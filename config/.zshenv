# $ZDOTDIR/.zshenv — sourced for every zsh shell, interactive or not.
# Keep this tight; interactive-only setup belongs in .zshrc and the numbered fragments.

# granted CLI: `assume` must be sourced (it mutates env in the calling shell), so it
# needs to exist for scripts that invoke it without -i.
alias assume=". assume"
