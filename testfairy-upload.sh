#!/bin/sh

UPLOADER_VERSION=1.10

# Put your TestFairy API_KEY here. Find it in your TestFairy account settings.
TESTFAIRY_API_KEY=

# Your Keystore, Storepass and Alias, the ones you use to sign your app.
KEYSTORE=
STOREPASS=
ALIAS=

# Tester Groups that will be notified when the app is ready. Setup groups in your TestFairy account testers page.
# This parameter is optional, leave empty if not required
TESTER_GROUPS=

# Should email testers about new version. Set to "off" to disable email notifications.
NOTIFY="on"

# If AUTO_UPDATE is "on" all users will be prompt to update to this build next time they run the app
AUTO_UPDATE="off"

# The maximum recording duration for every test. 
MAX_DURATION="10m"

# Is video recording enabled for this build 
VIDEO="on"

# Add a TestFairy watermark to the application icon?
ICON_WATERMARK="on"

# Comment text will be included in the email sent to testers
COMMENT=""

# locations of various tools
CURL=curl
ZIP=zip
KEYTOOL=keytool
ZIPALIGN=zipalign
JARSIGNER=jarsigner

SERVER_ENDPOINT=https://app.testfairy.com

usage() {
	echo "Usage: testfairy-upload.sh <command>"
	echo
	echo "Commands:"
	echo "  android <filename>"
	echo "  ios <filename>"
	echo
}
	
verify_tools() {
	# Windows users: this script requires zip, curl and sed. If not installed please get from http://cygwin.com/

	# Check 'curl' tool
	${CURL} --help >/dev/null
	if [ $? -ne 0 ]; then
		echo "Could not run curl tool, please check settings"
		exit 1
	fi

	if [ "$1" = "android" ]; then
		# Check 'zip' tool
		${ZIP} -h >/dev/null
		if [ $? -ne 0 ]; then
			echo "Could not run zip tool, please check settings"
			exit 1
		fi
		
		OUTPUT=$( ${JARSIGNER} -help 2>&1 | grep "verify" )
		if [ $? -ne 0 ]; then
			echo "Could not run jarsigner tool, please check settings"
			exit 1
		fi
		
		# Check 'zipalign' tool
		OUTPUT=$( ${ZIPALIGN} 2>&1 | grep -i "Zip alignment" )
		if [ $? -ne 0 ]; then
			echo "Could not run zipalign tool, please check settings"
			exit 1
		fi

		OUTPUT=$( ${KEYTOOL} -help 2>&1 | grep "keypasswd" )
		if [ $? -ne 0 ]; then
			echo "Could not run keytool tool, please check settings"
			exit 1
		fi
	fi
}

verify_settings() {
	if [ -z "${TESTFAIRY_API_KEY}" ]; then
		usage
		echo "Please update API_KEY with your private API key, as noted in the Settings page"
		exit 1
	fi

	if [ "$1" = "android" ]; then
		if [ -z "${KEYSTORE}" -o -z "${STOREPASS}" -o -z "{$ALIAS}" ]; then
			usage
			echo "Please update KEYSTORE, STOREPASS and ALIAS with your jar signing credentials"
			exit 1
		fi

		# verify KEYSTORE, STOREPASS and ALIAS at once
		OUTPUT=$( ${KEYTOOL} -list -keystore "${KEYSTORE}" -storepass "${STOREPASS}" -alias "${ALIAS}" 2>&1 )
		if [ $? -ne 0 ]; then
			usage
			echo "Please check keystore credentials; keytool failed to verify storepass and alias"
			exit 1
		fi
	fi
}

if [ $# -ne 2 ]; then
	usage
	exit 1
fi

PLATFORM=$1

# before even going on, make sure all tools work
verify_tools $PLATFORM
verify_settings $PLATFORM

BINARYFILE=$2

if [ ! -f "${BINARYFILE}" ]; then
	usage
	echo "Could not find file: ${BINARYFILE}"
	exit 2
fi

if [ "$PLATFORM" = "android" ]; then
	# temporary file paths
	DATE=`date`
	TMP_BINARYFILE=.testfairy.upload.apk
	ZIPALIGNED_BINARYFILE=.testfairy.zipalign.apk
	rm -f "${TMP_BINARYFILE}" "${ZIPALIGNED_BINARYFILE}"

	/bin/echo -n "Uploading ${BINARYFILE} to TestFairy.. "
	JSON=$( ${CURL} --http1.0 -s ${SERVER_ENDPOINT}/api/upload -F api_key=${TESTFAIRY_API_KEY} -F file="@${BINARYFILE}" -F icon-watermark="${ICON_WATERMARK}" -F video="${VIDEO}" -F max-duration="${MAX_DURATION}" -F comment="${COMMENT}" -A "TestFairy Command Line Uploader ${UPLOADER_VERSION}" )

	URL=$( echo ${JSON} | sed 's/\\\//\//g' | sed -n 's/.*"instrumented_url"\s*:\s*"\([^"]*\)".*/\1/p' )
	if [ -z "${URL}" ]; then
		echo "FAILED!"
		echo 
		echo "Upload failed, please check your settings"
		exit 1
	fi

	URL="${URL}?api_key=${TESTFAIRY_API_KEY}"

	echo "OK!"
	/bin/echo -n "Downloading instrumented APK.. "
	${CURL} -L -o ${TMP_BINARYFILE} -s ${URL}

	if [ ! -f "${TMP_BINARYFILE}" ]; then
		echo "FAILED!"
		echo
		echo "Could not download APK back from server, please contact support@testfairy.com"
		exit 1
	fi

	echo "OK!"

	/bin/echo -n "Re-signing APK file.. "
	${ZIP} -qd ${TMP_BINARYFILE} 'META-INF/*'
	${JARSIGNER} -keystore "${KEYSTORE}" -storepass "${STOREPASS}" -digestalg SHA1 -sigalg MD5withRSA ${TMP_BINARYFILE} "${ALIAS}"
	${JARSIGNER} -verify ${TMP_BINARYFILE} >/dev/null
	if [ $? -ne 0 ]; then
		echo "FAILED!"
		echo
		echo "Jarsigner failed to verify, please check parameters and try again"
		exit 1
	fi

	${ZIPALIGN} -f 4 ${TMP_BINARYFILE} ${ZIPALIGNED_BINARYFILE}
	rm -f ${TMP_BINARYFILE}
	echo "OK!"

	/bin/echo -n "Uploading signed APK to TestFairy.. "
	JSON=$( ${CURL} --http1.0 -s ${SERVER_ENDPOINT}/api/upload-signed -F api_key=${TESTFAIRY_API_KEY} -F file=@${ZIPALIGNED_BINARYFILE} -F testers-groups="${TESTER_GROUPS}" -F auto-update="${AUTO_UPDATE}" -F notify="${NOTIFY}")
	rm -f ${ZIPALIGNED_BINARYFILE}

	URL=$( echo ${JSON} | sed 's/\\\//\//g' | sed -n 's/.*"build_url"\s*:\s*"\([^"]*\)".*/\1/p' )
	if [ -z "$URL" ]; then
		echo "FAILED!"
		echo
		echo "Build uploaded, but no reply from server. Please contact support@testfairy.com"
		exit 1
	fi
elif [ "$PLATFORM" = "ios" ]; then
	/bin/echo -n "Uploading ${BINARYFILE} to TestFairy.. "
	JSON=$( ${CURL} --http1.0 -s ${SERVER_ENDPOINT}/api/upload -F api_key=${TESTFAIRY_API_KEY} -F file="@${BINARYFILE}" -F icon-watermark="${ICON_WATERMARK}" -F video="${VIDEO}" -F max-duration="${MAX_DURATION}" -F comment="${COMMENT}" -A "TestFairy Command Line Uploader ${UPLOADER_VERSION}")

	URL=$( echo ${JSON} | sed 's/\\\//\//g' | sed -n 's/.*"instrumented_url"\s*:\s*"\([^"]*\)".*/\1/p' )
	if [ -z "${URL}" ]; then
		echo "FAILED!"
		echo 
		echo "Upload failed, please check your settings"
		exit 1
	fi

	URL="${URL}?api_key=${TESTFAIRY_API_KEY}"

	echo "OK!"
else
	usage
	echo "Invalid command: '${PLATFORM}'"
	exit 3
fi

echo "OK!"
echo
echo "Build was successfully uploaded to TestFairy and is available at:"
echo ${URL}
