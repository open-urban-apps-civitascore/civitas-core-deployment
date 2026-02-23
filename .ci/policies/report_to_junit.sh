#!/bin/bash
set -euo pipefail

yaml_content=""
# either read from file or stdin and store in yaml_content
if [ -t 0 ]; then
    if [ -f "$1" ]; then
        yaml_content=$(cat "$1")
    else
        echo "Usage: $0 <yaml_file>"
        exit 1
    fi
else
    yaml_content=$(cat)
fi

# Start building the XML
echo '<?xml version="1.0" encoding="UTF-8"?>'
echo '<testsuites name="Test Results" tests="'$(echo "$yaml_content" | yq '.results | length')'" failures="'$(echo "$yaml_content" | yq '.summary.fail')'" errors="'$(echo "$yaml_content" | yq '.summary.warn')'" time="0">'

# Loop through each result
for i in $(seq 0 $(( $(echo "$yaml_content" | yq '.results | length') - 1 ))); do
    result=$(echo "$yaml_content" | yq ".results[$i]")
    category=$(echo "$result" | yq '.category')
    message=$(echo "$result" | yq '.message' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    rule=$(echo "$result" | yq '.rule' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    result_status=$(echo "$result" | yq '.result')
    severity=$(echo "$result" | yq '.severity' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

    if [ "$result_status" = "fail" ]; then
        echo "<testcase name=\"$rule\" classname=\"$category\">"
        echo "<failure message=\"$message\" type=\"$severity\">"
        echo "$message"
        echo "</failure>"
        echo "</testcase>"
    elif [ "$result_status" = "pass" ] && [ "$severity" != "warn" ]; then
        echo "<testcase name=\"$rule\" classname=\"$category\"/>"
    elif [ "$severity" = "warn" ]; then
        echo "<testcase name=\"$rule\" classname=\"$category\">"
        echo "<error message=\"$message\" type=\"$severity\">"
        echo "$message"
        echo "</error>"
        echo "</testcase>"
    fi
done

echo '</testsuites>'
