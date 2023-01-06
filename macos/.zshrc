# Enable CLI coloring
export CLICOLOR=1

# For Homebrew
export HOMEBREW_PREFIX="/opt/homebrew"
export HOMEBREW_CELLAR="/opt/homebrew/Cellar"
export HOMEBREW_REPOSITORY="/opt/homebrew"
export HOMEBREW_SHELLENV_PREFIX="/opt/homebrew"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin${PATH+:$PATH}"
export MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:"
export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}"

export PATH=$(pyenv root)/shims:$PATH

# The following three checks are in place due to OS updates occasionally resetting the sshd_config file to default.
# For security, Amazon suggests that password authentication over SSH be disabled.
if sudo sshd -T | grep -x --quiet "passwordauthentication yes"; then
  echo "WARNING: Password-based authentication enabled over SSH! This can be insecure and should be disabled in /etc/ssh/sshd_config"
fi

if sudo sshd -T | grep -x --quiet "challengeresponseauthentication yes"; then
  echo "WARNING: Challenge Response Authentication enabled over SSH! This can be insecure and should be disabled in /etc/ssh/sshd_config"
fi

if sudo sshd -T | grep -x --quiet "usepam yes"; then
  echo "WARNING: Use of Pluggable Authentication Module (PAM) submethod enabled over SSH! This can be insecure and should be disabled in /etc/ssh/sshd_config"
fi


[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"  # This loads nvm bash_completion

