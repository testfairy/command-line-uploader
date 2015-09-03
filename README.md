TestFairy Command Line Uploader
===============================

TestFairy's Command Line Uploader is a shell script to upload your IPA or APK files to TestFairy for monitoring and distribution.

There are 3 shell scripts in this repository:

* `testfairy-upload-ios.sh`
  Will upload IPA files to TestFairy for distribution.

* `testfairy-upload-android.sh`
  Will upload APK files to TestFairy. Will sign the APK with your keystore and certificate.

* `testfairy-upload-android-advanced.sh`
  Same as above, but will use minimal bandwidth. Use for large files.

When working with these shells scripts, notice that you will have to edit them and provide your **API KEY** and (optionally) other values such as testers groups to invite, metrics to record and other settings.

Support 
=======

For support, please visit our FAQ at http://docs.testfairy.com/FAQ.html
For questions not covered there, please contact support via the developer dashboard.

License
=======

Released under Apache License.
