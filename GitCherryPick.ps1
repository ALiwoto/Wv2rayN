param(
    [string]$RemoteName = "official",
    [string]$RemoteBranch = "master",
    [string]$StartCommit = $null
)

# If StartCommit is null, get the last commit on the current branch
if (!$StartCommit) {
    $StartCommit = git rev-parse HEAD
    $targetMessage = git log --format=%B -n 1 $StartCommit
    $targetMessage = $targetMessage.Replace("`n", " ")

    # now we should try to see which original commit, this commit
    # been cherry-picked from
    # in the commit message, it should have something like this:
    # (cherry picked from commit <commit-hash>)
    $messageMatches = [regex]::Matches($targetMessage, "cherry picked from commit ([a-f0-9]+)")
    if ($messageMatches.Count -eq 1) {
        $StartCommit = $messageMatches[0].Groups[1].Value
    } else {
        throw 'Could not find the original commit hash in the commit message'
        exit 1
    }


    Write-Host "Using the last commit on the current branch: $StartCommit" -ForegroundColor Yellow
} else {
    Write-Host "Using provided start commit: $StartCommit" -ForegroundColor Yellow
}

$futureCommits = git rev-list --reverse "$StartCommit..$RemoteName/$RemoteBranch"

if (!$futureCommits) {
    Write-Host "No new commits to cherry-pick, you are all good!" -ForegroundColor Green
    exit 0
}

foreach ($currentCommit in $futureCommits) {
    Write-Host "Cherry-picking commit: $currentCommit"

    $originalCommitMessage = git log --format=%B -n 1 $currentCommit

    # Prepare the new commit message with the original hash
    $newMessage = "$originalCommitMessage`n`n(cherry picked from commit $currentCommit)"

    $gitOutput = (& git cherry-pick $currentCommit 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Cherry-pick failed, please resolve the conflicts!" -ForegroundColor Red
        exit 1
    }
    Write-Host $gitOutput

    # now we should change the commit message
    git commit --amend -m $newMessage
}