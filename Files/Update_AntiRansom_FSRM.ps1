set-FsrmFileGroup -name "Anti-Ransomware File Groups" -IncludePattern @((Invoke-WebRequest -Uri "https://fsrm.experiant.ca/api/v1/get" -UseBasicParsing).content | convertfrom-json | % {$_.filters})