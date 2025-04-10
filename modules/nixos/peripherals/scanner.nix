{
  x.global.email.accounts."scanner@systems.tbx.at" = {
    permissions.send = true;

    secrets = {
      passwordLength = 32;
      passwordsContainSpecialChars = false; # Surprise: The scanner can't deal with special chars in the password. 🤦
    };
  };
}
