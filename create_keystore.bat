@echo off
echo Creating keystore for Mosaic Search app...
echo.
echo You will be asked for the following information:
echo 1. Keystore password (choose a strong password)
echo 2. Key password (can be the same as keystore password)
echo 3. Your first and last name
echo 4. Your organizational unit (can be "Development")
echo 5. Your organization name (can be your name or company)
echo 6. Your city or locality
echo 7. Your state or province
echo 8. Your country code (e.g., US, IN, UK)
echo.
echo IMPORTANT: Remember your passwords! You'll need them to update your app later.
echo.
pause

cd android
"C:\Program Files\Android\Android Studio\jbr\bin\keytool" -genkey -v -keystore app-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

echo.
echo Keystore created successfully!
echo Now you need to update the key.properties file with your actual passwords.
echo.
pause 