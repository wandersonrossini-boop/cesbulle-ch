while (Get-Process | Where-Object { $_.Name -like "*dart*" }) {
    Start-Sleep -Seconds 5
}
cmd /c "C:\Users\Wande\AppData\Roaming\npm\firebase.cmd deploy --only hosting --project cme-lausanne-mvp-12345"
