# ----- About: ----
    # Get MaxValue Plus Report  
    # Revision v08 - 2021-05-02
    # Author: Eric Harless, Head Backup Nerd - N-able 
    # Twitter @Backup_Nerd  Email:eric.harless@n-able.com
# -----------------------------------------------------------#>  ## About

<# ----- Legal: ----
    # Sample scripts are not supported under any N-able support program or service.
    # The sample scripts are provided AS IS without warranty of any kind.
    # N-able expressly disclaims all implied warranties including, warranties
    # of merchantability or of fitness for a particular purpose. 
    # In no event shall N-able or any other party be liable for damages arising
    # out of the use of or inability to use the sample scripts.
# -----------------------------------------------------------#>  ## Legal

<# ----- Compatibility: ----
    # For use with the Standalone edition of N-able Backup
# -----------------------------------------------------------#>  ## Compatibility

<# ----- Behavior: ----
    # Check/ Get/ Store secure credentials 
    # Authenticate to https://backup.management console
    # Check partner level/ Enumerate partners/ GUI select partner
    # Enumerate devices/ GUI select devices
    # Get Maximum Value Report for Period
    # Get Current Device Statistics
    # Optionally export to XLS/CSV
    #
    # Use the -MaxValue parameter set to export an enhanced MaxValue report
    # Use the -DPP parameters set to export Data Protection Plan values from a combined MaxValue and device export
    #   Use the -Period switch parameter to define DPP & MaxValue Dates (yyyy-MM or MM-yyyy)
    # Use the -Current parameter set to Export current device values
    #   Use the -Current parameter set witht he -AllDevices switch parameter to skip GUI device selection
    # Use the -AllPartners switch parameter to skip GUI partner selection
    # Use the -DeviceCount ## (default=20000) parameter to define the maximum number of devices returned
    # Use the -Launch switch parameter to launch the XLS/CSV file after completion
    # Use the -Delimiter (default=',') parameter to set the delimiter for XLS/CSV output (i.e. use ';' for The Netherlands)
    # Use the -ExportPath (?:\Folder) parameter to specify XLS/CSV file path
    # Use the -ClearCredentials parameter to remove stored API credentials at start of script
    #
    # https://documentation.n-able.com/backup/userguide/documentation/Content/service-management/json-api/home.htm
    # https://documentation.n-able.com/backup/userguide/documentation/Content/service-management/json-api/API-column-codes.htm
    # https://documentation.n-able.com/backup/userguide/documentation/Content/service-management/console/export.htm


# -----------------------------------------------------------#>  ## Behavior

[CmdletBinding(DefaultParameterSetName="Data Protection Plan Usage")]
    Param (
        
        [Parameter(ParameterSetName="Data Protection Plan Usage",Mandatory=$False)] [Switch]$DPP,                       ## Export Monthly Data Protection Plan Usage
        [Parameter(ParameterSetName="MaxValue Usage",Mandatory=$False)] [Switch]$MaxValue,                              ## Export Monthly Max Value Report
        [Parameter(ParameterSetName="Current Usage",Mandatory=$False)] [Switch]$Current,                                ## Export Current Usage
        [Parameter(ParameterSetName="Data Protection Plan Usage",Mandatory=$False)]
            [Parameter(ParameterSetName="MaxValue Usage",Mandatory=$False)] [datetime]$Period = (Get-Date),             ## Lookup Date yyyy-MM or MM-yyyy
        [Parameter(Mandatory=$False)] [switch]$AllPartners,                                                             ## Skip GUI partner selection
        [Parameter(ParameterSetName="Current Usage",Mandatory=$False)] [switch]$AllDevices,                             ## Skip GUI device selection  
        [Parameter(Mandatory=$False)] [int]$DeviceCount = 20000,                                                        ## Change Maximum Number of current devices results to return
        [Parameter(Mandatory=$False)] [switch]$Launch,                                                                  ## Launch XLS or CSV file 
        [Parameter(Mandatory=$False)] [string]$Delimiter = ',',                                                         ## specify ',' or ';' Delimiter for XLS & CSV file   
        [Parameter(Mandatory=$False)] $ExportPath = "$PSScriptRoot",                                                    ## Export Path
        [Parameter(Mandatory=$False)] [switch]$ClearCredentials                                                         ## Remove Stored API Credentials at start of script
    )

#region ----- Environment, Variables, Names and Paths ----
    Clear-Host
    $ConsoleTitle = "Get Max Value Plus Device Statistics Report"
    $host.UI.RawUI.WindowTitle = $ConsoleTitle
    Write-output "  $ConsoleTitle`n`n"
    $Syntax = Get-Command $PSCommandPath -Syntax ; Write-Output "  Script Parameter Syntax:`n`n$Syntax"

    Write-output "  Current Parameters:"
    Write-output "  -Mode        = $($PSCmdlet.ParameterSetName)"  
    Write-output "  -Period      = $($period.ToString('yyyy-MM-dd'))"
    Write-output "  -AllPartners = $AllPartners"
    Write-output "  -AllDevices  = $AllDevices"
    Write-output "  -DeviceCount = $DeviceCount"
    Write-output "  -Launch      = $Launch"
    Write-output "  -ExportPath  = $ExportPath"
    Write-output "  -Delimiter   = $Delimiter"

    $scriptpath = $MyInvocation.MyCommand.Path
    $dir = Split-Path $scriptpath
    Push-Location $dir
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Script:strLineSeparator = "  ---------"
    $CurrentDate = Get-Date -format "yyy-MM-dd_hh-mm-ss"
    $urljson = "https://api.backup.management/jsonapi"

#endregion ----- Environment, Variables, Names and Paths ----

#region ----- Functions ----

#region ----- Authentication ----
    Function Set-APICredentials {

        Write-Output $Script:strLineSeparator 
        Write-Output "  Setting Backup API Credentials" 
        if (Test-Path $APIcredpath) {
            Write-Output $Script:strLineSeparator 
            Write-Output "  Backup API Credential Path Present" }else{ New-Item -ItemType Directory -Path $APIcredpath} 
 
            Write-Output "  Enter Exact, Case Sensitive Partner Name for N-able Backup.Management API i.e. 'Acme, Inc (bob@acme.net)'"
        DO{ $Script:PartnerName = Read-Host "  Enter Login Partner Name" }
        WHILE ($PartnerName.length -eq 0)
        $PartnerName | out-file $APIcredfile

        $BackupCred = Get-Credential -UserName "" -Message 'Enter Login Email and Password for N-able Backup.Management API'
        $BackupCred | Add-Member -MemberType NoteProperty -Name PartnerName -Value "$PartnerName" 

        $BackupCred.UserName | Out-file -append $APIcredfile
        $BackupCred.Password | ConvertFrom-SecureString | Out-file -append $APIcredfile
        
        Start-Sleep -milliseconds 300

        Send-APICredentialsCookie  ## Attempt API Authentication

    }  ## Set API credentials if not present

    Function Get-APICredentials {

        $Script:True_path = "C:\ProgramData\MXB\"
        $Script:APIcredfile = join-path -Path $True_Path -ChildPath "$env:computername API_Credentials.Secure.txt"
        $Script:APIcredpath = Split-path -path $APIcredfile
    
        if (($ClearCredentials) -and (Test-Path $APIcredfile)) { 
            Remove-Item -Path $Script:APIcredfile
            $ClearCredentials = $Null
            Write-Output $Script:strLineSeparator 
            Write-Output "  Backup API Credential File Cleared"
            Send-APICredentialsCookie  ## Retry Authentication
            
            }else{ 
                Write-Output $Script:strLineSeparator 
                Write-Output "  Getting Backup API Credentials" 
            
                if (Test-Path $APIcredfile) {
                    Write-Output    $Script:strLineSeparator        
                    "  Backup API Credential File Present"
                    $APIcredentials = get-content $APIcredfile
                    
                    $Script:cred0 = [string]$APIcredentials[0] 
                    $Script:cred1 = [string]$APIcredentials[1]
                    $Script:cred2 = $APIcredentials[2] | Convertto-SecureString 
                    $Script:cred2 = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Script:cred2))
    
                    Write-Output    $Script:strLineSeparator 
                    Write-output "  Stored Backup API Partner  = $Script:cred0"
                    Write-output "  Stored Backup API User     = $Script:cred1"
                    Write-output "  Stored Backup API Password = Encrypted"
                    
                }else{
                    Write-Output    $Script:strLineSeparator 
                    Write-Output "  Backup API Credential File Not Present"
    
                    Set-APICredentials  ## Create API Credential File if Not Found
                    }
                }
    
    }  ## Get API credentials if present

    Function Send-APICredentialsCookie {

    Get-APICredentials  ## Read API Credential File before Authentication

    $url = "https://api.backup.management/jsonapi"
    $data = @{}
    $data.jsonrpc = '2.0'
    $data.id = '2'
    $data.method = 'Login'
    $data.params = @{}
    $data.params.partner = $Script:cred0
    $data.params.username = $Script:cred1
    $data.params.password = $Script:cred2

    $webrequest = Invoke-WebRequest -Method POST `
        -ContentType 'application/json' `
        -Body (ConvertTo-Json $data) `
        -Uri $url `
        -SessionVariable Script:websession `
        -UseBasicParsing
        $Script:cookies = $websession.Cookies.GetCookies($url)
        $Script:websession = $websession
        $Script:Authenticate = $webrequest | convertfrom-json

    #Debug Write-output "$($Script:cookies[0].name) = $($cookies[0].value)"

    if ($authenticate.visa) { 

        $Script:visa = $authenticate.visa
        $Script:UserId = $authenticate.result.result.id
        }else{
            Write-Output    $Script:strLineSeparator 
            Write-output "  Authentication Failed: Please confirm your Backup.Management Partner Name and Credentials"
            Write-output "  Please Note: Multiple failed authentication attempts could temporarily lockout your user account"
            Write-Output    $Script:strLineSeparator 
            
            Set-APICredentials  ## Create API Credential File if Authentication Fails
        }

    }  ## Use Backup.Management credentials to Authenticate

#endregion ----- Authentication ----

#region ----- Data Conversion ----
Function Convert-UnixTimeToDateTime($inputUnixTime){
    if ($inputUnixTime -gt 0 ) {
    $epoch = Get-Date -Date "1970-01-01 00:00:00Z"
    $epoch = $epoch.ToUniversalTime()
    $DateTime = $epoch.AddSeconds($inputUnixTime)
    return $DateTime
    }else{ return ""}
}  ## Convert epoch time to date time 

Function Convert-DateTimeToUnixTime($DateToConvert) {
    $epoch = Get-Date -Date "1970-01-01 00:00:00Z"
    $NewExtensionDate = Get-Date -Date $DateToConvert
    [int64]$NewEpoch = (New-TimeSpan -Start $epoch -End $NewExtensionDate).TotalSeconds
    Return $NewEpoch
}  ## Convert date time to epoch time


#endregion ----- Data Conversion ----

#region ----- Backup.Management JSON Calls ----

    Function Send-GetPartnerInfo ($PartnerName) { 
                    
        $url = "https://api.backup.management/jsonapi"
        $data = @{}
        $data.jsonrpc = '2.0'
        $data.id = '2'
        $data.visa = $Script:visa
        $data.method = 'GetPartnerInfo'
        $data.params = @{}
        $data.params.name = [String]$PartnerName

        $webrequest = Invoke-WebRequest -Method POST `
            -ContentType 'application/json' `
            -Body (ConvertTo-Json $data -depth 5) `
            -Uri $url `
            -SessionVariable Script:websession `
            -UseBasicParsing
            #$Script:cookies = $websession.Cookies.GetCookies($url)
            $Script:websession = $websession
            $Script:Partner = $webrequest | convertfrom-json

        $RestrictedPartnerLevel = @("Root","SubRoot","Distributor")

        if ($Partner.result.result.Level -notin $RestrictedPartnerLevel) {
            [String]$Script:Uid = $Partner.result.result.Uid
            [int]$Script:PartnerId = [int]$Partner.result.result.Id
            [String]$Script:Level = $Partner.result.result.Level
            [String]$Script:PartnerName = $Partner.result.result.Name

            Write-Output $Script:strLineSeparator
            Write-output "  $PartnerName - $partnerId - $Uid"
            Write-Output $Script:strLineSeparator
            }else{
            Write-Output $Script:strLineSeparator
            Write-Host "  Lookup for $($Partner.result.result.Level) Partner Level Not Allowed"
            Write-Output $Script:strLineSeparator
            $Script:PartnerName = Read-Host "  Enter EXACT Case Sensitive Customer/ Partner displayed name to lookup i.e. 'Acme, Inc (bob@acme.net)'"
            Send-GetPartnerInfo $Script:partnername
            }

        if ($partner.error) {
            write-output "  $($partner.error.message)"
            $Script:PartnerName = Read-Host "  Enter EXACT Case Sensitive Customer/ Partner displayed name to lookup i.e. 'Acme, Inc (bob@acme.net)'"
            Send-GetPartnerInfo $Script:partnername

        }

    } ## get PartnerID and Partner Level    

    Function CallJSON($url,$object) {

        $bytes = [System.Text.Encoding]::UTF8.GetBytes($object)
        $web = [System.Net.WebRequest]::Create($url)
        $web.Method = "POST"
        $web.ContentLength = $bytes.Length
        $web.ContentType = "application/json"
        $stream = $web.GetRequestStream()
        $stream.Write($bytes,0,$bytes.Length)
        $stream.close()
        $reader = New-Object System.IO.Streamreader -ArgumentList $web.GetResponse().GetResponseStream()
        return $reader.ReadToEnd()| ConvertFrom-Json
        $reader.Close()
    }

    Function Send-EnumeratePartners {
        # ----- Get Partners via EnumeratePartners -----
        
        # (Create the JSON object to call the EnumeratePartners function)
            $objEnumeratePartners = (New-Object PSObject | Add-Member -PassThru NoteProperty jsonrpc '2.0' |
                Add-Member -PassThru NoteProperty visa $Script:visa |
                Add-Member -PassThru NoteProperty method 'EnumeratePartners' |
                Add-Member -PassThru NoteProperty params @{
                                                            parentPartnerId = $PartnerId 
                                                            fetchRecursively = "false"
                                                            fields = (0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22) 
                                                            } |
                Add-Member -PassThru NoteProperty id '1')| ConvertTo-Json -Depth 5
        
        # (Call the JSON Web Request Function to get the EnumeratePartners Object)
                [array]$Script:EnumeratePartnersSession = CallJSON $urlJSON $objEnumeratePartners
        
                $Script:visa = $EnumeratePartnersSession.visa
        
                #Write-Output    $Script:strLineSeparator
                #Write-Output    "  Using Visa:" $Script:visa
                #Write-Output    $Script:strLineSeparator
        
        # (Added Delay in case command takes a bit to respond)
                Start-Sleep -Milliseconds 100
        
        # (Get Result Status of EnumerateAccountProfiles)
                $EnumeratePartnersSessionErrorCode = $EnumeratePartnersSession.error.code
                $EnumeratePartnersSessionErrorMsg = $EnumeratePartnersSession.error.message
        
        # (Check for Errors with EnumeratePartners - Check if ErrorCode has a value)
                if ($EnumeratePartnersSessionErrorCode) {
                    Write-Output    $Script:strLineSeparator
                    Write-Output    "  EnumeratePartnersSession Error Code:  $EnumeratePartnersSessionErrorCode"
                    Write-Output    "  EnumeratePartnersSession Message:  $EnumeratePartnersSessionErrorMsg"
                    Write-Output    $Script:strLineSeparator
                    Write-Output    "  Exiting Script"
        # (Exit Script if there is a problem)
        
                    #Break Script
                }
                    Else {
        # (No error)
        
                $Script:EnumeratePartnersSessionResults = $EnumeratePartnersSession.result.result | select-object Name,@{l='Id';e={($_.Id).tostring()}},Level,ExternalCode,ParentId,LocationId,* -ExcludeProperty Company -ErrorAction Ignore
                
                $Script:EnumeratePartnersSessionResults | ForEach-Object {$_.CreationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.CreationTime))}
                $Script:EnumeratePartnersSessionResults | ForEach-Object { if ($_.TrialExpirationTime  -ne "0") { $_.TrialExpirationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.TrialExpirationTime))}}
                $Script:EnumeratePartnersSessionResults | ForEach-Object { if ($_.TrialRegistrationTime -ne "0") {$_.TrialRegistrationTime = [timezone]::CurrentTimeZone.ToLocalTime(([datetime]'1/1/1970').AddSeconds($_.TrialRegistrationTime))}}
            
                $Script:SelectedPartners = $EnumeratePartnersSessionResults | Select-object * | Where-object {$_.name -notlike "001???????????????- Recycle Bin"} | Where-object {$_.Externalcode -notlike '`[??????????`]* - ????????-????-????-????-????????????'}
                        
                $Script:SelectedPartner = $Script:SelectedPartners += @( [pscustomobject]@{Name=$PartnerName;Id=[string]$PartnerId;Level='<ParentPartner>'} ) 
                
                
                if ($AllPartners) {
                    $Script:Selection = $Script:SelectedPartners |Select-object id,Name,Level,CreationTime,State,TrialRegistrationTime,TrialExpirationTime,Uid | sort-object Level,name
                    Write-Output    $Script:strLineSeparator
                    Write-Output    "  All Partners Selected"
                }else{
                    $Script:Selection = $Script:SelectedPartners |Select-object id,Name,Level,CreationTime,State,TrialRegistrationTime,TrialExpirationTime,Uid | sort-object Level,name | out-gridview -Title "Current Partner | $partnername" -OutputMode Single
            
                    if($null -eq $Selection) {
                        # Cancel was pressed
                        # Run cancel script
                        Write-Output    $Script:strLineSeparator
                        Write-Output    "  No Partners Selected"
                        Exit
                    }
                    else {
                        # OK was pressed, $Selection contains what was chosen
                        # Run OK script
                        [int]$Script:PartnerId = $Script:Selection.Id
                        [String]$Script:PartnerName = $Script:Selection.Name
                    }
                }

        }
        
    }  ## EnumeratePartners API Call

    Function Send-GetDevices {

        $url = "https://api.backup.management/jsonapi"
        $data = @{}
        $data.jsonrpc = '2.0'
        $data.id = '2'
        $data.visa = $visa
        $data.method = 'EnumerateAccountStatistics'
        $data.params = @{}
        $data.params.query = @{}
        $data.params.query.PartnerId = [int]$PartnerId
        $data.params.query.Filter = $Filter1
        $data.params.query.Columns = @("AU","AR","AN","MN","AL","LN","OP","OI","OS","OT","PD","AP","PF","PN","CD","TS","TL","T3","US","I81","AA843","AA77","AA2048")
        $data.params.query.OrderBy = "CD DESC"
        $data.params.query.StartRecordNumber = 0
        $data.params.query.RecordsCount = $devicecount
        $data.params.query.Totals = @("COUNT(AT==1)","SUM(T3)","SUM(US)")
    
        $webrequest = Invoke-WebRequest -Method POST `
        -ContentType 'application/json' `
        -Body (ConvertTo-Json $data -depth 6) `
        -Uri $url `
        -WebSession $websession `
        -UseBasicParsing
        $Script:cookies = $websession.Cookies.GetCookies($url)
        $Script:websession = $websession
    
        #Write-output "$($Script:cookies[0].name) = $($cookies[0].value)"
    
        $Script:Devices = $webrequest | convertfrom-json
        #$Script:visa = $authenticate.visa
                
        $Script:DeviceDetail = @()

        ForEach ( $DeviceResult in $Devices.result.result ) {
        $Script:DeviceDetail += New-Object -TypeName PSObject -Property @{ AccountID      = [Int]$DeviceResult.AccountId;
                                                                    PartnerID      = [string]$DeviceResult.PartnerId;
                                                                    DeviceName     = $DeviceResult.Settings.AN -join '' ;
                                                                    ComputerName   = $DeviceResult.Settings.MN -join '' ;
                                                                    DeviceAlias    = $DeviceResult.Settings.AL -join '' ;
                                                                    PartnerName    = $DeviceResult.Settings.AR -join '' ;
                                                                    Reference      = $DeviceResult.Settings.PF -join '' ;
                                                                    Creation       = Convert-UnixTimeToDateTime ($DeviceResult.Settings.CD -join '') ;
                                                                    TimeStamp      = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TS -join '') ;  
                                                                    LastSuccess    = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TL -join '') ;                                                                                                                                                                                                               
                                                                    SelectedGB     = [Math]::Round([Decimal](($DeviceResult.Settings.T3 -join '') /1GB),2) ;                        
                                                                    UsedGB         = [Math]::Round([Decimal](($DeviceResult.Settings.US -join '') /1GB),2) ;  
                                                                    DataSources    = $DeviceResult.Settings.AP -join '' ;                                                                
                                                                    Account        = $DeviceResult.Settings.AU -join '' ;
                                                                    Location       = $DeviceResult.Settings.LN -join '' ;
                                                                    Notes          = $DeviceResult.Settings.AA843 -join '' ;
                                                                    GUIPassword    = $DeviceResult.Settings.AA2048 -join '' ;                                                                    
                                                                    TempInfo       = $DeviceResult.Settings.AA77 -join '' ;
                                                                    Product        = $DeviceResult.Settings.PN -join '' ;
                                                                    ProductID      = $DeviceResult.Settings.PD -join '' ;
                                                                    Profile        = $DeviceResult.Settings.OP -join '' ;
                                                                    OS             = $DeviceResult.Settings.OS -join '' ;                                                                
                                                                    OSType         = $DeviceResult.Settings.OT -join '' ;
                                                                    Physicality    = $DeviceResult.Settings.I81 -join '' ;         
                                                                    ProfileID      = $DeviceResult.Settings.OI -join '' }
        }
    

       

    } ## EnumerateAccountStatistics API Call

    Function Send-GetDeviceHistory {
        $history = (get-date $period)


        $url = "https://api.backup.management/jsonapi"
        $data = @{}
        $data.jsonrpc = '2.0'
        $data.id = '2'
        $data.visa = $visa
        $data.method = 'EnumerateAccountHistoryStatistics'
        $data.params = @{}
        $data.params.timeslice = Convert-DateTimeToUnixTime $History
        $data.params.query = @{}
        $data.params.query.PartnerId = [int]$PartnerId
        $data.params.query.Filter = $Filter1
        $data.params.query.Columns = @("AU","AR","AN","MN","AL","LN","OP","OI","OS","OT","PD","AP","PF","PN","CD","TS","TL","T3","US","I81","AA843","AA77","AA2048")
        $data.params.query.OrderBy = "CD DESC"
        $data.params.query.StartRecordNumber = 0
        $data.params.query.RecordsCount = $devicecount
        $data.params.query.Totals = @("COUNT(AT==1)","SUM(T3)","SUM(US)")
    
        $webrequest = Invoke-WebRequest -Method POST `
        -ContentType 'application/json' `
        -Body (ConvertTo-Json $data -depth 6) `
        -Uri $url `
        -WebSession $websession `
        -UseBasicParsing
        $Script:cookies = $websession.Cookies.GetCookies($url)
        $Script:websession = $websession
    
        #Write-output "$($Script:cookies[0].name) = $($cookies[0].value)"
    
        $Script:Devices = $webrequest | convertfrom-json
        #$Script:visa = $authenticate.visa
                
        $Script:DeviceDetail = @()

        ForEach ( $DeviceResult in $Devices.result.result ) {
        $Script:DeviceDetail += New-Object -TypeName PSObject -Property @{ AccountID      = [Int]$DeviceResult.AccountId;
                                                                    PartnerID      = [string]$DeviceResult.PartnerId;
                                                                    DeviceName     = $DeviceResult.Settings.AN -join '' ;
                                                                    ComputerName   = $DeviceResult.Settings.MN -join '' ;
                                                                    DeviceAlias    = $DeviceResult.Settings.AL -join '' ;
                                                                    PartnerName    = $DeviceResult.Settings.AR -join '' ;
                                                                    Reference      = $DeviceResult.Settings.PF -join '' ;
                                                                    Creation       = Convert-UnixTimeToDateTime ($DeviceResult.Settings.CD -join '') ;
                                                                    TimeStamp      = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TS -join '') ;  
                                                                    LastSuccess    = Convert-UnixTimeToDateTime ($DeviceResult.Settings.TL -join '') ;                                                                                                                                                                                                               
                                                                    SelectedGB     = [Math]::Round([Decimal](($DeviceResult.Settings.T3 -join '') /1GB),2) ;                        
                                                                    UsedGB         = [Math]::Round([Decimal](($DeviceResult.Settings.US -join '') /1GB),2) ;  
                                                                    DataSources    = $DeviceResult.Settings.AP -join '' ;                                                                
                                                                    Account        = $DeviceResult.Settings.AU -join '' ;
                                                                    Location       = $DeviceResult.Settings.LN -join '' ;
                                                                    Notes          = $DeviceResult.Settings.AA843 -join '' ;
                                                                    GUIPassword    = $DeviceResult.Settings.AA2048 -join '' ;                                                                    
                                                                    TempInfo       = $DeviceResult.Settings.AA77 -join '' ;
                                                                    Product        = $DeviceResult.Settings.PN -join '' ;
                                                                    ProductID      = $DeviceResult.Settings.PD -join '' ;
                                                                    Profile        = $DeviceResult.Settings.OP -join '' ;
                                                                    OS             = $DeviceResult.Settings.OS -join '' ;                                                                
                                                                    OSType         = $DeviceResult.Settings.OT -join '' ;
                                                                    Physicality    = $DeviceResult.Settings.I81 -join '' ;         
                                                                    ProfileID      = $DeviceResult.Settings.OI -join '' }
        }
    

       

    } ## EnumerateAccountStatistics API Call

    Function GetMVReport {
        Param ([Parameter(Mandatory=$False)][Int]$PartnerId) #end param
            

        $Start = (Get-Date $period -Day 1).AddMonths(0).ToString('yyyy-MM-dd')
        $End = (Get-Date $period -Day 1).AddMonths(1).AddDays(-1).ToString('yyyy-MM-dd')
        $Script:TempMVReport = "c:\windows\temp\TempMVReport.xlsx"
        
        Write-Output "  Requesting Maximum Value Report from $start to $end"

        $Script:url2 = "https://api.backup.management/statistics-reporting/high-watermark-usage-report?_=6e8d1e0fce68d&dateFrom=$($Start)T00%3A00%3A00Z&dateTo=$($end)T23%3A59%3A59Z&exportOutput=OneXlsxFile&partnerId=$($PartnerId)"
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Cookie", "__cfduid=d7cfe7579ba7716fe73703636ea50b1251593338423; visa=$Script:visa")

        Write-output  "$url2"

        Invoke-RestMethod -Uri $url2 `
        -Method GET `
        -Headers $headers `
        -ContentType 'application/json' `
        -WebSession $websession `
        -OutFile $Script:TempMVReport 
      
        if (Get-Module -ListAvailable -Name ImportExcel) {
            Write-Host "  Module ImportExcel Already Installed"
        } 
        else {
            try {
                Install-Module -Name ImportExcel -Confirm:$False -Force      ## https://powershell.one/tricks/parsing/excel
            }
            catch [Exception] {
                $_.message 
                exit
            }
        }

        $Script:MVReportxls = Import-Excel -path "$Script:TempMVReport" -asDate "*Date" 

        $Script:MVReport = $Script:MVReportxls | select-object *,@{n='PhysicalServer';e='Null'},@{n='VirtualServer';e='Null'},@{n='Workstation';e='Null'},@{n='Documents';e='Null'}   

        $Script:MVReport | foreach-object { if ($_.RecoveryTesting -eq "False"){$_.RecoveryTesting = $null}}
        $Script:MVReport | foreach-object { if ($_.RecoveryTesting -eq "True"){$_.RecoveryTesting = "1"}}
        $Script:MVReport | foreach-object { if ($_.O365Users -eq "0"){$_.O365Users = $null}}

    } 

    Function Join-Reports {

        Install-module -name Join-Object  
        $Script:MVPlus = Join-Object -left $Script:MVReport -right $Script:SelectedDevices -LeftJoinProperty DeviceId -RightJoinProperty AccountID -Prefix 'Now_' -Type AllInBoth

    }


#endregion ----- Backup.Management JSON Calls ----

#endregion ----- Functions ----

    Switch ($PSCmdlet.ParameterSetName) { 
        'Data Protection Plan Usage' {

            Send-APICredentialsCookie

            Write-Output $Script:strLineSeparator
            Write-Output ""
            
            Send-GetPartnerInfo $Script:cred0
                    
            if ($AllPartners) {}else{Send-EnumeratePartners}
            
            Send-GetDevices $partnerId
            
            $Script:SelectedDevices = $DeviceDetail | Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,OSType,Physicality

            GetMVReport $partnerId
            join-reports
            
            if($null -eq $SelectedDevices) {
                # Cancel was pressed
                # Run cancel script
                Write-Output    $Script:strLineSeparator
                Write-Output    "  No Devices Selected"
                Exit
            }else{
                # OK was pressed, $Selection contains what was chosen
                # Run OK script
                
            }
        
            $Script:csvoutputfile = "$ExportPath\$($CurrentDate)_MaxValuePlus_DPP_$($period.ToString('yyyy-MM'))_Statistics_$($Partnername -replace(`" \(.*\)`",`"`") -replace(`"[^a-zA-Z_0-9]`",`"`"))_$($PartnerId).csv"
        
            $Script:MVPlus | foreach-object { if (($_.OsType -eq "Server") -and ($_.Now_Physicality -eq "Physical")) {$_.PhysicalServer = "1"}}
            $Script:MVPlus | foreach-object { if (($_.OsType -eq "Server") -and ($_.Now_Physicality -eq "Virtual")) {$_.VirtualServer = "1"}}
            $Script:MVPlus | foreach-object { if (($_.OsType -eq "Workstation") -and ($_.Now_Product -eq "Documents")) {$_.Documents = "1"}}
            $Script:MVPlus | foreach-object { if (($_.OsType -eq "Workstation") -and ($_.Now_Product -ne "Documents")) {$_.Workstation = "1"}}
            
            $Script:MVPlus | Where-object {$_.CustomerState -eq "InProduction"} | Select-object Parent1Name,CustomerName,ComputerName,DeviceName,DeviceId,OsType,Now_Physicality,PhysicalServer,VirtualServer,Workstation,Documents,RecoveryTesting,O365Users,CustomerState,CreationDate,ProductionDate,DeviceDeletionDate,Now_Product,SelectedSizeGB,UsedStorageGB | Export-CSV -path "$csvoutputfile" -delimiter "$Delimiter" -NoTypeInformation -Encoding UTF8
        
            $Script:xlsoutputfile = $csvoutputfile.Replace("csv","xlsx")
        
            $Script:MVPlus | Where-object {$_.CustomerState -eq "InProduction"} | Select-object Parent1Name,CustomerName,ComputerName,DeviceName,DeviceId,OsType,Now_Physicality,PhysicalServer,VirtualServer,Workstation,Documents,RecoveryTesting,O365Users,CustomerState,CreationDate,ProductionDate,DeviceDeletionDate,Now_Product,SelectedSizeGB,UsedStorageGB | Export-Excel -Path "$xlsoutputfile" -AutoFilter -AutoSize -TableName BackupUsage -FreezeTopRowFirstColumn -WorksheetName (get-date $period -UFormat "%b-%Y") -tablestyle Medium6 -BoldTopRow -IncludePivotTable -PivotRows Parent1Name,CustomerName -PivotDataToColumn -PivotData @{PhysicalServer='sum';VirtualServer='sum';Workstation='sum';Documents='sum';RecoveryTesting='sum';O365Users='sum'}
                
            }
        'MaxValue Usage' { 
            
            Send-APICredentialsCookie

            Write-Output $Script:strLineSeparator
            Write-Output "" 
            
            Send-GetPartnerInfo $Script:cred0
                    
            if ($AllPartners) {}else{Send-EnumeratePartners}
            
            Send-GetDevices $partnerId
            
            $Script:SelectedDevices = $DeviceDetail | Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,OSType,Physicality

            GetMVReport $partnerId
            join-reports
            
            if($null -eq $SelectedDevices) {
                # Cancel was pressed
                # Run cancel script
                Write-Output    $Script:strLineSeparator
                Write-Output    "  No Devices Selected"
                Exit
            }else{
                # OK was pressed, $Selection contains what was chosen
                # Run OK script
            
            }

            $Script:csvoutputfile = "$ExportPath\$($CurrentDate)_MaxValuePlus_$($period.ToString('yyyy-MM'))_Statistics_$($Partnername -replace(`" \(.*\)`",`"`") -replace(`"[^a-zA-Z_0-9]`",`"`"))_$($PartnerId).csv"

            $Script:MVPlus | foreach-object { if (($_.OsType -eq "Server") -and ($_.Now_Physicality -eq "Physical")) {$_.PhysicalServer = "1"}}
            $Script:MVPlus | foreach-object { if (($_.OsType -eq "Server") -and ($_.Now_Physicality -eq "Virtual")) {$_.VirtualServer = "1"}}
            $Script:MVPlus | foreach-object { if (($_.OsType -eq "Workstation") -and ($_.Now_Product -eq "Documents")) {$_.Documents = "1"}}
            $Script:MVPlus | foreach-object { if (($_.OsType -eq "Workstation") -and ($_.Now_Product -ne "Documents")) {$_.Workstation = "1"}}

            $Script:MVPlus | Select-object * | Export-CSV -path "$csvoutputfile" -delimiter "$Delimiter" -NoTypeInformation -Encoding UTF8
            
            $Script:xlsoutputfile = $csvoutputfile.Replace("csv","xlsx")

            $Script:MVPlus | Select-object * | Export-Excel -Path "$xlsoutputfile" -AutoFilter -AutoSize -TableName BackupUsage -FreezeTopRowFirstColumn -WorksheetName (get-date $period -UFormat "%b-%Y") -tablestyle Medium6 -BoldTopRow -IncludePivotTable -PivotRows Parent1Name,CustomerName -PivotDataToColumn -PivotData @{PhysicalServer='sum';VirtualServer='sum';Workstation='sum';Documents='sum';RecoveryTesting='sum';O365Users='sum'}
            
            }
        'Current Usage' { 
        
            Send-APICredentialsCookie

            Write-Output $Script:strLineSeparator
            Write-Output "" 
            
            Send-GetPartnerInfo $Script:cred0
            
            
            if ($AllPartners) {}else{Send-EnumeratePartners}
            
            Send-GetDevices $partnerId
            
            if ($AllDevices) {
                $Script:SelectedDevices = $DeviceDetail | Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,OSType,Physicality
                    
            }else{
                $Script:SelectedDevices = $DeviceDetail | Select-Object PartnerId,PartnerName,Reference,AccountID,DeviceName,ComputerName,Creation,TimeStamp,LastSuccess,ProductId,Product,ProfileId,Profile,DataSources,SelectedGB,UsedGB,Location,OS,OSType,Physicality | Out-GridView -title "Current Partner | $partnername" -OutputMode Multiple}
            
            if($null -eq $SelectedDevices) {
                # Cancel was pressed
                # Run cancel script
                Write-Output    $Script:strLineSeparator
                Write-Output    "  No Devices Selected"
                Exit
            }else{
                # OK was pressed, $Selection contains what was chosen
                # Run OK script
            
            }
            
            $Script:csvoutputfile = "$ExportPath\$($CurrentDate)_Statistics_$($Partnername -replace(`" \(.*\)`",`"`") -replace(`"[^a-zA-Z_0-9]`",`"`"))_$($PartnerId).csv"
            $Script:SelectedDevices | Select-object * | Export-CSV -path "$csvoutputfile" -delimiter "$Delimiter" -NoTypeInformation -Encoding UTF8

            $Script:xlsoutputfile = $csvoutputfile.Replace("csv","xlsx")

            $Script:SelectedDevices | Select-object * | Export-Excel -Path "$xlsoutputfile" -AutoFilter -AutoSize -TableName BackupUsage -FreezeTopRowFirstColumn -WorksheetName (get-date $period -UFormat "%b-%Y") -tablestyle Medium6 -BoldTopRow

            }

    }

    ## Launch CSV or XLS (if Excel is installed)  (Required -Launch Parameter)
        
    if ($Launch) {
        If (test-path HKLM:SOFTWARE\Classes\Excel.Application) { 
            Start-Process "$xlsoutputfile"
            Write-output $Script:strLineSeparator
            Write-Output "  Opening XLS file"
            }else{
            Start-Process "$csvoutputfile"
            Write-output $Script:strLineSeparator
            Write-Output "  Opening CSV file"
            Write-output $Script:strLineSeparator            
            }
        }
        
    Write-output $Script:strLineSeparator
    Write-Output "  CSV Path = $csvoutputfile"
    Write-Output "  XLS Path = $xlsoutputfile"
    Write-Output ""
    
    Start-Sleep -seconds 10


