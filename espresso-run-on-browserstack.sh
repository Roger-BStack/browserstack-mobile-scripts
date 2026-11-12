#!/usr/bin/env bash

APK_PATH=./apps/app-debug.apk
TEST_APK_PATH=./apps/app-debug-androidTest.apk


set -e

#-1 upload app
upload_app=$(curl --no-progress-meter -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" -X POST "https://api-cloud.browserstack.com/app-automate/espresso/v2/app" -F "file=@$APK_PATH")
app_url=$(echo $upload_app | jq -r .app_url)

echo "\napp_url: $app_url\n"


#-2 upload test
upload_test=$(curl --no-progress-meter -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" -X POST "https://api-cloud.browserstack.com/app-automate/espresso/v2/test-suite" -F "file=@$TEST_APK_PATH")
test_url=$(echo $upload_test | jq -r .test_suite_url)

echo "\ntest_url: $test_url\n"


#-3 trigger test
browserstack_build_request=$(cat <<EOF
{
    "devices": [
        "Google Pixel 9-16.0"
    ],
    "app": "$app_url",
    "testSuite": "$test_url",
    "debug": "true",
    "project": "Espresso Script Tests",
    "package": [
        "com.sample.browserstack.samplecalculator"
    ],
    "shards": {"numberOfShards": 3}
}
EOF
)
echo "$browserstack_build_request"
trigger_tests=$(curl --no-progress-meter -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" \
    -X POST "https://api-cloud.browserstack.com/app-automate/espresso/v2/build" \
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

    build_response=$( curl --no-progress-meter -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" -X GET "https://api-cloud.browserstack.com/app-automate/espresso/v2/builds/$build_id")
    status=$( echo "$build_response" | jq -r .status )
    if [ "$status" == "running" ]; then
        echo " - Still running, waiting . . ."
        sleep 30;
    elif [ "$status" == "null" ]; then
        echo "\Waiting for build $build_id to start:\n"
        echo "$build_response"

        sleep 30;
    elif [ "$status" == "passed" ]; then
        exit_code=0
        break
    else
        echo "Non-passing status: $status"
        break
    fi
done;

test_result_url="https://app-automate.browserstack.com/dashboard/v2/builds/$build_id"
echo "status: $status"
echo "\nCheck the test result from Browserstack: \n - $test_result_url"
exit $exit_code