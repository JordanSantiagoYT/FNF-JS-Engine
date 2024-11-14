:: Original from: https://github.com/PatoFlamejanteTV/ImaturidadePlusPlus/blob/main/coisaslegal/message.bat
:: MessageBox System, make (mainly) for ImaturidadePlusPlus
:: By: PatoFlamejanteTV, made ONLY by me
:: ----------------------------------------------------------------------------------
@echo off
IF EXIST temp.vbs (
    del temp.vbs
)
echo x=msgbox("%1" ,%3, "%2") >> temp.vbs
start temp.vbs
echo DEBUG: Message: %1, Title: %2.
:: del temp.vbs
:: message.bat Die ? 48
:: ^ .bat Name ^   ^  ^- Icon and Other Stuff (eg. "48 for Warning Message icon")
::             |   |- Title (eg. "...")
::             |- Content/Message/Text (eg. "I-N-F-E-C-T-E-D")
:: ----------------------------------------------------------------------------------
:: pause :: skibidi ohio sigma pomni goofy debug line