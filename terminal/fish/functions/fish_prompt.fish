# Strata — prompt sur deux lignes : chemin (ciel) puis ❯ (violet, rouge si échec)
function fish_prompt
    set -l last_status $status
    set -l sky 7FB2E5
    set -l violet B58AD6
    set -l red C8553D
    set -l gold E8B23A
    set -l dim B8A88C

    echo
    set_color $sky
    echo -n (prompt_pwd --full-length-dirs 2)
    # branche git discrète
    if command -q git; and set -l branch (git branch --show-current 2>/dev/null)
        set_color $dim; echo -n " on "
        set_color $gold; echo -n " $branch"
    end
    if test $last_status -ne 0
        set_color $red; echo -n " [$last_status]"
    end
    echo
    if test $last_status -eq 0
        set_color $violet
    else
        set_color $red
    end
    echo -n '❯ '
    set_color normal
end
