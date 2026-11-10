# Issue tracker: GitHub

Issues and specifications for this repository are GitHub issues. Use the `gh` command for all operations. The repository is `micfre/efficient-quests`. If `gh` needs the repository name, read it from `git remote -v`.

## Commands

- Create an issue: `gh issue create --title "..." --body "..."`. For a body of more than one line, use a heredoc.
- Read an issue: `gh issue view <number> --json number,title,body,labels,comments`.
- List issues: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'`. Add `--label` and `--state` filters as needed.
- Comment on an issue: `gh issue comment <number> --body "..."`.
- Add or remove a label: `gh issue edit <number> --add-label "..."` or `gh issue edit <number> --remove-label "..."`.
- Close an issue: `gh issue close <number> --comment "..."`.

## Sub-issues

A sub-issue is an issue that belongs to a parent issue. To make an issue a sub-issue, use one of these methods:

- With `gh` 2.94 or later, run `gh issue create --parent <parent> ...`. To change an existing issue, run `gh issue edit <parent> --add-sub-issue <child>`.
- With an older `gh`, run `gh api --method POST repos/<owner>/<repo>/issues/<parent>/sub_issues -F sub_issue_id=<child-db-id>`. The value `<child-db-id>` is the database ID of the child. The section on blocking below shows how to find a database ID.
- If sub-issues are not available, write `Part of #<parent>` at the top of the child body.

## Pull requests as a triage surface

PRs as a request surface: no.

Change this value to `yes` if the repository treats external pull requests as feature requests. The `/triage` command reads this value. If the value is `yes`, pull requests use the same labels and states as issues. Use these `gh pr` commands:

- Read a pull request: `gh pr view <number> --comments`. To read the diff, run `gh pr diff <number>`.
- List external pull requests for triage: `gh api --paginate 'repos/{owner}/{repo}/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, author_association, labels: [.labels[].name]}'`.
- Comment, label, or close: `gh pr comment`, `gh pr edit --add-label`, `gh pr edit --remove-label`, and `gh pr close`.

GitHub uses one number space for issues and pull requests. A number such as `#42` can be either one. To find out which, run `gh pr view 42`. If that fails, run `gh issue view 42`.

## When a skill says "publish to the issue tracker"

Create a GitHub issue.

## When a skill says "fetch the relevant ticket"

Read the issue with the command in the Commands section.

## Wayfinding operations

The `/wayfinder` command uses these operations. A map is one issue. Its child issues are the tickets.

- Map: One issue with the label `wayfinder:map`. Its body has the sections Notes, Decisions-so-far, and Fog. Create it with `gh issue create --label wayfinder:map`.
- Child ticket: An issue that is a sub-issue of the map. See the Sub-issues section. If sub-issues are not enabled, add the child to a task list in the map body. Also write `Part of #<map>` at the top of the child body. Give the child the label `wayfinder:<type>`, where the type is `research`, `prototype`, `grilling`, or `task`. When a developer claims a ticket, assign the ticket to that developer.
- Blocking: Use the native issue dependencies of GitHub. They are the standard way to record blocking, and the GitHub interface shows them. To add a dependency, run `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`. The value `<blocker-db-id>` is the numeric database ID of the blocker. It is not the `#number` and it is not the `node_id`. To get it, run `gh api repos/<owner>/<repo>/issues/<n> --jq .id`. GitHub reports `issue_dependencies_summary.blocked_by`. This value counts open blockers only, so it shows whether a ticket is blocked now. If dependencies are not available, write `Blocked by: #<n>, #<n>` at the top of the child body. A ticket is unblocked when every blocker is closed.
- Frontier query: The frontier is the set of tickets that are ready to start. To find it, list the open children of the map with `gh issue list --state open`. Limit the list to the sub-issues or the task list of the map. Remove each ticket that has an open blocker or an assignee. A ticket has an open blocker if `issue_dependencies_summary.blocked_by` is above 0, or if an open issue is in its `Blocked by` line. Of the tickets that remain, take the first one in map order.
- Claim: Run `gh issue edit <n> --add-assignee @me`. This is the first write of the session.
- Resolve: Run `gh issue comment <n> --body "<answer>"`. Then run `gh issue close <n>`. Then add a context pointer (a gist and a link) to the Decisions-so-far section of the map.
