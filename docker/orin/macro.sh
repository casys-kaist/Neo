# move to directories
alias workspace="cd /workspace"

alias neo-sw-frontend="cd /workspace/src/app/neo_sw/neo_sw_frontend"
alias neo-sw-backend="cd /workspace/src/app/neo_sw/neo_sw_backend"

alias gaussian-splatting-frontend="cd /workspace/src/app/gaussian_splatting/gaussian_splatting_frontend"
alias gaussian-splatting-backend="cd /workspace/src/app/gaussian_splatting/gaussian_splatting_backend"

# install python packages
alias pypkg-install="pip install -e . --index-url https://pypi.jetson-ai-lab.io/jp6/cu126"
alias update-packages="neo-sw-frontend && pypkg-install && \
                        neo-sw-backend && pypkg-install && \
                        gaussian-splatting-frontend && pypkg-install && \
                        gaussian-splatting-backend && pypkg-install && \
                        workspace && pypkg-install"

# bashrc shortcuts
alias update-bash="source ~/.bashrc"
alias edit-bash="vim ~/.bashrc"

# code formatting
alias format-check="workspace && make format && cd -"
