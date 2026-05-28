{ writeTextFile }:

# Hand-rolled fish completion for `just`.
#
# Replaces the nixpkgs default (`JUST_COMPLETE=fish just | source`), which
# registers an unconditional `complete -c just -a '(...)'` directive — that
# fires at *every* argument position and floods our hierarchical completions
# for `just update` with the full recipe list.
writeTextFile {
  name = "just-completions";
  destination = "/share/fish/vendor_completions.d/just.fish";
  text = ''
    function __just_complete_recipes
        just --list 2>/dev/null | string replace -rf '^\s+(\S+)([^#\n]*)(?:#\s+(.*))?$' '$1\t$3'
    end

    function __just_flake_packages
        nix eval --impure --json --apply 'pkgs: builtins.attrNames pkgs.''${builtins.currentSystem}' '.#packages' 2>/dev/null | jq -r '.[]' 2>/dev/null
    end

    # Recipe name completion — only when no recipe has been chosen yet.
    complete -c just -f -n '__fish_use_subcommand' -ka '(__just_complete_recipes)'

    # Hierarchical completions for `just update <target> <subtype> <package>`.
    function __just_at_update --description "True when completing the next arg of `just update`"
        set -l tokens (commandline -opc)
        set -l n (count $argv)
        set -l expected (math 2 + $n)
        test (count $tokens) -eq $expected; or return 1
        test "$tokens[2]" = update; or return 1
        for i in (seq 1 $n)
            set -l idx (math 2 + $i)
            test "$tokens[$idx]" = "$argv[$i]"; or return 1
        end
    end

    complete -c just -n '__just_at_update'             -fka nix
    complete -c just -n '__just_at_update nix'         -fka flake
    complete -c just -n '__just_at_update nix flake'   -fka '(__just_flake_packages)'
  '';
}
