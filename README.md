command-line-uploader
=====================

Upload your builds to Testfairy from command-line

#Usage

**Android**

Complete the config.ini file with your Testfairy API key & Android sign keys. For testing i'll be using android default sign keys;
```ini
TESTFAIRY_API_KEY = 
KEYSTORE =/Users/vruno/.android/debug.keystore
STOREPASS =android
ALIAS =androiddebugkey
TESTER_GROUPS =
```
and run;
```bash
./testfairy-upload.sh /path/to/your/app.apk
```


**iOS**

For iOS you just have to complete the config.ini file with your Testfairy API key and run
```bash
./testfairy-upload.sh /path/to/your/app.ipa
```
