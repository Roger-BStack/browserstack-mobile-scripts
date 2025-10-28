#!/usr/bin/env bash

IPA_PATH=./apps/ios.ipa
TEST_ZIP_PATH=./apps/xcui.zip


set -e

#-1 upload app
upload_app=$(curl --no-progress-meter -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" -X POST "https://api-cloud.browserstack.com/app-automate/xcuitest/v2/app" -F "file=@$IPA_PATH")
app_url=$(echo $upload_app | jq -r .app_url)

echo "\napp_url: $app_url\n"


#-2 upload test
upload_test=$(curl --no-progress-meter -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" -X POST "https://api-cloud.browserstack.com/app-automate/xcuitest/v2/test-suite" -F "file=@$TEST_ZIP_PATH")
test_url=$(echo $upload_test | jq -r .test_suite_url)

echo "\ntest_url: $test_url\n"


#-3 trigger test
browserstack_build_request=$(cat <<EOF
{
    "devices": [
        "iPhone 13-15", 
        "iPhone 14-16"
    ],
    "app": "$app_url",
    "testSuite": "$test_url",
    "debug": "true",
    "project": "XCTest Script Tests"
}
EOF
)
echo "$browserstack_build_request"
trigger_tests=$(curl --no-progress-meter -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" \
    -X POST "https://api-cloud.browserstack.com/app-automate/xcuitest/v2/build" \
    -d "$browserstack_build_request" \
    -H "Content-Type: application/json")
build_id=$(echo $trigger_tests | jq -r .build_id)

echo "\ntrigger_tests: $trigger_tests\n"
echo "\nbuild_id: $build_id\n"


#-4 wait for tests to finish, checking every 30 secs until timeout of 1800 secs (30mins)
end=$((SECONDS+1800))
exit_code=1
status="not run"
while true
do 
    if [ $SECONDS -gt $end ]; then
        echo " - Timeout for Test RUN!"
        break
    fi

    status=$( curl --no-progress-meter -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" -X GET "https://api-cloud.browserstack.com/app-automate/xcuitest/v2/builds/$build_id" | jq -r .status )
    if [ "$status" == "running" ]; then
        echo " - Still running, waiting . . ."
        sleep 30;
    elif [ "$status" == "passed" ]; then
        exit_code=0
        break
    else
        break
    fi
done;

test_result_url="https://app-automate.browserstack.com/dashboard/v2/builds/$build_id"
echo "status: $status"
echo "\nCheck the test result from Browserstack: \n - $test_result_url"
exit $exit_code