#!/bin/sh

# Put your TestFairy API_KEY here. Find it in your TestFairy account settings.
TESTFAIRY_API_KEY=

# Tester Groups that will be notified when the app is ready. Setup groups in your TestFairy account testers page.
TESTER_GROUPS=

# Your Keystore, Storepass and Alias, the ones you use to sign your app.
KEYSTORE=
STOREPASS=
ALIAS=

# locations of various tools
CURL=curl
ZIP=zip
KEYTOOL=keytool
ZIPALIGN=zipalign
JARSIGNER=jarsigner

SERVER_ENDPOINT=https://app.testfairy.com

usage() {
	echo "Usage: testfairy-upload.sh APK_FILENAME"
	echo
}
	
verify_tools() {

	# Check 'zip' tool
	${ZIP} -h >/dev/null
	if [ $? -ne 0 ]; then
		echo "Could not run zip tool, please check settings"
		exit 1
	fi
	
	# Check 'curl' tool
	${CURL} --help >/dev/null
	if [ $? -ne 0 ]; then
		echo "Could not run curl tool, please check settings"
		exit 1
	fi
	
	OUTPUT=$( ${JARSIGNER} -help 2>&1 )
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

	OUTPUT=$( ${KEYTOOL} -help 2>&1 )
	if [ $? -ne 0 ]; then
		echo "Could not run keytool tool, please check settings"
		exit 1
	fi
}

verify_settings() {
	if [ -z "${TESTFAIRY_API_KEY}" ]; then
		usage
		echo "Please update API_KEY with your private API key, as noted in the Settings page"
		exit 1
	fi

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
}

if [ $# -ne 1 ]; then
	usage
	exit 1
fi

# before even going on, make sure all tools work
verify_tools
verify_settings

APK_FILENAME=$1
if [ ! -f "${APK_FILENAME}" ]; then
	usage
	echo "Can't find file: ${APK_FILENAME}"
	exit 2
fi

# temporary file paths
TMP_FILENAME=.testfairy.upload.apk
ZIPALIGNED_FILENAME=.testfairy.zipalign.apk
rm -f "${TMP_FILENAME}" "${ZIPALIGNED_FILENAME}"

/bin/echo -n "Uploading ${APK_FILENAME} to TestFairy.. "
JSON=$( ${CURL} -s ${SERVER_ENDPOINT}/api/upload -F api_key=${TESTFAIRY_API_KEY} -F apk_file=@${APK_FILENAME} )

URL=$( echo ${JSON} | sed 's/\\\//\//g' | sed -n 's/.*"instrumented_url"\s*:\s*"\([^"]*\)".*/\1/p' )
if [ -z "${URL}" ]; then
	echo "FAILED!"
	echo 
	echo "Upload failed, please check your settings"
	exit 1
fi

echo "OK!"
/bin/echo -n "Downloading instrumented APK.. "
${CURL} -o ${TMP_FILENAME} -s ${URL}
echo "OK!"

/bin/echo -n "Re-signing APK file.. "
${ZIP} -qd ${TMP_FILENAME} 'META-INF/*'
${JARSIGNER} -keystore "${KEYSTORE}" -storepass "${STOREPASS}" -digestalg SHA1 -sigalg MD5withRSA ${TMP_FILENAME} "${ALIAS}"
${JARSIGNER} -verify ${TMP_FILENAME} >/dev/null
if [ $? -ne 0 ]; then
	echo "FAILED!"
	echo
	echo "Jarsigner failed to verify, please check parameters and try again"
	exit 1
fi

${ZIPALIGN} -f 4 ${TMP_FILENAME} ${ZIPALIGNED_FILENAME}
rm -f ${TMP_FILENAME}
echo "OK!"

/bin/echo -n "Uploading signed APK to TestFairy.. "
JSON=$( ${CURL} -s ${SERVER_ENDPOINT}/api/upload-signed -F api_key=${TESTFAIRY_API_KEY} -F apk_file=@${ZIPALIGNED_FILENAME} -F testers-groups="${TESTER_GROUPS}" )
rm -f ${ZIPALIGNED_FILENAME}

URL=$( echo ${JSON} | sed 's/\\\//\//g' | sed -n 's/.*"build_url"\s*:\s*"\([^"]*\)".*/\1/p' )
if [ -z "$URL" ]; then
	echo "FAILED!"
	echo
	echo "Build uploaded, but no reply from server. Please contact support@testfairy.com"
	exit 1
fi

echo "OK!"
echo
echo "Build was successfully uploaded to TestFairy and is available at:"
echo ${URL}
