const expresssession = require('express-session')
const DynamDBStore = require('dynamodb-store')
const cookieparser = require('cookie-parser')
const bodyparser = require('body-parser')
const env = require('node-env-file')
const express = require('express')
const path = require('path')

env(path.join(__dirname, 'settings.sh'))

const app = express()

app.set('views', path.join(__dirname, 'views'))
app.set('view engine', 'ejs')
app.use(express.static('public'))
app.use(cookieparser())
app.use(bodyparser.urlencoded({ extended: true }))

const options = {
    table: {
        name: process.env.TABLE_NAME,
        hashKey: 'id',
        hashPrefix: '',
        readCapacityUnits: 2,
        writeCapacityUnits: 2
    },
    dynamoConfig: {
        accessKeyId: process.env.ACCESS_KEY_ID,
        secretAccessKey: process.env.SECRET_ACCESS_KEY,
        region: process.env.AWS_REGION,
        endpoint: 'http://dynamodb.' + process.env.AWS_REGION + '.amazonaws.com'
    },
    keepExpired: false,
    touchInterval: 30000,
    ttl: 8000 // 8 seconds
}

app.use(expresssession({
    name: 'session',
    secret: `secret-${Math.random().toString().substr(7)}`,
    /*
     * Forces a session that is "uninitialized" to be saved to the store. 
     * A session is uninitialized when it is new but not modified. 
     * Choosing false is useful for implementing login sessions, reducing server storage 
     * usage, or complying with laws that require permission before setting a cookie.
     * The default value is true.
     */
    saveUninitialized: false,
    /*
     * Forces the session to be saved back to the session store, even if
     * the session was never modified during the request.
     * The default value is true, but using the default has been deprecated, 
     * as the default will change in the future.
     * Typically, you'll want false.
     */
    resave: false,
    store: new DynamDBStore(options)
}))

app.use(function (req, res, next) {

    console.log('middleware call at:', (new Date().toISOString()).substr(11, 12), 'for url:', req.url)
    //console.log(req.cookies)
    // default values for `req.session.data`
    var data = { views: 1, user: null }
    // update values if `req.session.data` has already been defined
    if (req.session.data != undefined) {
        data = {
            views: req.session.data.views + 1,
            user: req.session.data.user
        }
    }
    req.session.data = data

    console.log('middleware set req.session.data:', req.session.data)
    next()
})

function getLog(req) {
    let obj = {
        cookies: 'undefined',
        data: JSON.stringify(req.session.data, null, 2)
    }
    if (req.cookies != undefined && Object.keys(req.cookies).length > 0) {
        obj.cookies = JSON.stringify(req.cookies, null, 2)
    }
    return obj
}

app.get('/', (req, res) => {
    console.log('GET / req.session.data:', req.session.data)

    res.render('index', {
        data: req.session.data,
        log: getLog(req),
        quicklogin: true
    })
})

app.get('/login', (req, res) => {
    console.log('GET /login req.session.data:', req.session.data)

    res.render('login', {
        data: req.session.data,
        error: null,
        log: getLog(req)
    })
})

app.get('/quicklogin/:username', (req, res) => {
    // ignore this page view 
    req.session.data.views--

    let username = req.params.username
    let password = ''
    if (username == 'a' || username == 'b') {
        req.session.data.user = username
    }

    res.redirect('/')
})

/*
    2 availables users:
    - username: `a` with password: `a`
    - username: `b` with password: `b`
*/
app.post('/login', (req, res) => {
    console.log('POST /login req.session.data:', req.session.data)
    let { username, password } = req.body
    let error = null
    if (username == '' || password == '') {
        error = 'Input missing'
    } else if (username != 'a' && username != 'b') {
        error = 'Invalid user'
    } else if (username != password) {
        error = 'Invalid password'
    }

    if (error == null) {
        req.session.data.user = username
        res.redirect('/')
    } else {
        res.render('login', {
            data: req.session.data,
            error,
            log: getLog(req),
        })
    }
})

app.get('/logout', (req, res) => {
    console.log('GET /logout req.session.data:', req.session.data)

    // destroy the session
    req.session.destroy(function (err) {
        // cannot access session here
        res.clearCookie('session')
        res.redirect('/')
    })
})

app.get('/restricted', (req, res) => {
    console.log('GET /restricted req.session.data:', req.session.data)

    let obj = {
        data: req.session.data,
        error: null,
        log: getLog(req),
    }

    if (req.session.data.user == null) {
        obj.error = 'This is a restrcited area'
    }

    res.render('restricted', obj)
})

app.listen(3000, () => {
    console.log('http://localhost:3000')
})