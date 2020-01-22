# the directory of his script file
dir="$(cd "$(dirname "$0")"; pwd)"

cd "$dir"

source settings.sample.sh

#
# create an AWS user
#

USER_NAME=aws-dynamodb-cognito-$(cat /dev/urandom | tr -dc 'a-z' | fold -w 6 | head -n 1)

echo 'iam create-user'
aws iam create-user \
    --user-name $USER_NAME

echo 'iam create-login-profile'
aws iam create-login-profile \
    --user-name $USER_NAME \
    --password $USER_NAME

echo 'iam create-access-key'
aws iam create-access-key \
    --user-name $USER_NAME \
    > accesskey.json

#
# create settings.sh
#

# get the AWS root account id
AWS_ID=$(aws sts get-caller-identity \
    --output text \
    --query 'Account')

ACCESS_KEY_ID=$(jq --raw-output \
    '.AccessKey.AccessKeyId' \
    accesskey.json)

SECRET_ACCESS_KEY=$(jq --raw-output \
    '.AccessKey.SecretAccessKey' \
    accesskey.json)

echo 'sed > settings.sh'
sed --expression "s|AWS_ID=.*$|AWS_ID=$AWS_ID|" \
    --expression "s|USER_NAME=.*$|USER_NAME=$USER_NAME|" \
    --expression "s|ACCESS_KEY_ID=.*$|ACCESS_KEY_ID=$ACCESS_KEY_ID|" \
    --expression "s|SECRET_ACCESS_KEY=.*$|SECRET_ACCESS_KEY=$SECRET_ACCESS_KEY|" \
    settings.sample.sh \
    > settings.sh

#
# add inline policy to the user
#

source settings.sh

echo 'sed > policy.json'
sed --expression "s|AWS_REGION|$AWS_REGION|" \
    --expression "s|AWS_ID|$AWS_ID|" \
    --expression "s|TABLE_NAME|$TABLE_NAME|" \
    policy.sample.json \
    > policy.json

echo 'iam put-user-policy'
aws iam put-user-policy \
    --user-name $USER_NAME \
    --policy-name policy \
    --policy-document file://policy.json