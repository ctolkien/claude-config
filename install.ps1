# Links every skill in this repo into ~/.claude/skills using directory junctions
# (no admin or Developer Mode needed). Safe to re-run.
$ErrorActionPreference = 'Stop'
$skillsHome = Join-Path $HOME '.claude\skills'
New-Item -ItemType Directory -Force $skillsHome | Out-Null

foreach ($skill in Get-ChildItem (Join-Path $PSScriptRoot 'skills') -Directory) {
    $link = Join-Path $skillsHome $skill.Name
    $existing = Get-Item $link -ErrorAction SilentlyContinue
    if ($existing -and $existing.LinkType -eq 'Junction' -and $existing.Target -eq $skill.FullName) {
        Write-Host "ok      $($skill.Name)"
        continue
    }
    if ($existing) {
        Write-Warning "skip    $($skill.Name): $link already exists and isn't a link to this repo"
        continue
    }
    New-Item -ItemType Junction -Path $link -Target $skill.FullName | Out-Null
    Write-Host "linked  $($skill.Name)"
}
