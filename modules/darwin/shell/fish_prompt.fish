function fish_prompt
	set -l last_pipestatus $pipestatus
	set -l last_exit $status

    function _set_color_dimmed_text
        set_color --bold cccccc
    end

	# Necessary for detecting if in fish prompt from other functions
	set -x in_fish_prompt 0

	if set -q VIRTUAL_ENV
		set_color --bold bryellow
		echo -n "py("
		_set_color_dimmed_text
		echo -n (basename "$VIRTUAL_ENV")
		set_color --bold bryellow
		echo -n ") "
		set_color normal
	end

	function _is_git_clean
		return (git status -s | wc -l)
	end

	function _git_branch_name
		set -l branch (git symbolic-ref --quiet HEAD)
		if set -q branch[1]
			string replace -r '^refs/heads/' '' $branch
		else
			git rev-parse --short HEAD
		end
		# git rev-parse --abbrev-ref HEAD
	end

	function _print_git_branch_status
		set -l a (_git_branch_name)
		set -l b origin/(_git_branch_name)

		set -l base ( git merge-base $a $b )
		set -l aref ( git rev-parse  $a    )
		set -l bref ( git rev-parse  $b    )

		if [ "$aref" = "$bref" ]
		#	echo up-to-date
		else if [ "$aref" = "$base" ]
			echo -n "|🔻"  # Remote is ahead
		else if [ "$bref" = "$base" ]
			echo -n "|🔺"  # Remote is behind
		else
			echo -n "|❗"  # Remote and local have diverged
		end
	end

	if git rev-parse --git-dir > /dev/null 2>&1  # We're in a git repo
		set_color --bold 6ED4FB
		echo -n -s "git("
        _set_color_dimmed_text
        echo -n -s (_git_branch_name)
		set_color --bold 6ED4FB

		if not _is_git_clean
			echo -n "|⚠️"
		end

		if not git status -sb | grep "## No commits yet" > /dev/null 2>&1  # There is at least one commit (to avoid weird errors)
			if [ (git rev-parse --abbrev-ref HEAD) != "HEAD" ]  # We're not in detached HEAD state
				set -l git_remote "remotes/origin/"(_git_branch_name)
				if git branch -a | grep $git_remote > /dev/null 2>&1
					_print_git_branch_status
				end
			end
		end

		echo -n ") "
		set_color normal
	end


	if echo "$last_pipestatus" | grep -qvE '^0( 0)*$'
		__fish_print_pipestatus "exit(" ") " "|" (set_color --bold f5abb9) (_set_color_dimmed_text) $last_pipestatus
	end


	if [ $last_exit = 0 ]
		set_color green
		echo -n ":>"
	else
		set_color red
		echo -n ":<"

	end
	echo -n " "
	set_color normal
end
