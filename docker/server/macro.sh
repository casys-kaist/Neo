# move to directories
alias workspace="cd /workspace"

# install python packages
alias update-packages="workspace && uv sync --group neo --reinstall && cd -"

# bashrc shortcuts
alias update-bash="source ~/.bashrc"
alias edit-bash="vim ~/.bashrc"

# code formatting
alias format-check="workspace && uv run make format && cd -"
