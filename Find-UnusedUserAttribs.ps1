$RootDsn = Get-ADRootDSE
$BaseDn = $RootDsn.defaultNamingContext
$SchemaDn = $RootDsn.schemaNamingContext
$FilePath = "C:\temp\result.txt"

Function Get-AuxClasses
{
    $Private:Outs= @()
    $Private:theClass =Get-ADObject -SearchBase $SchemaDn -Filter {name -like "User"} -Properties systemAuxiliaryClass,auxiliaryClass
    $oClass = $null

    foreach($oClass in $Private:theClass.systemAuxiliaryClass)
    {
         $Private:Outs += $oClass
    }

    $oClass = $null

    foreach($oClass in $Private:theClass.auxiliaryClass)

    {
        $Private:Outs += $oClass
    }
    return $Private:Outs
}

Function Get-AvailableUserAttrib
{
    $result = Get-ADObject -SearchBase (Get-ADRootDSE).SchemaNamingContext -Filter {name -like "User"} -Properties MayContain,SystemMayContain |

    Select-Object @{n="Attributes";e={$_.maycontain + $_.systemmaycontain}} | Select-Object -ExpandProperty Attributes | Sort-Object
    $oAux = Get-AuxClasses

    Foreach ($_ in $oAux)
    {
        $result += $_
    }
    return $result
}

Function Find-AllUnused-New
{
    $attributes = Get-AvailableUserAttrib
    $attributesHash = @{}

    foreach ($attribute in $attributes)
    {
     $attributesHash.add($attribute,0)
    }

    $users = Get-ADUser -Filter *
    $TotalUsers = $users.Count
    $CheckedUsers = 0

    Write-Host Found $TotalUsers users objects to check

    "Found $TotalUsers users objects to check" | Out-File -FilePath $FilePath

    Foreach ($user in $users){
        $userAD = Get-ADUser -Filter {sAMAccountName -eq $user.sAMAccountName} -Properties *
        Foreach ($a in $attributes)
        {
            [string] $value = $userAD.$a
            $IsInUse = $false
            $IsInUse = Is-InUse $value

            if ($IsInUse -eq $True)
            {
                $attributesHash[$a] = $attributesHash[$a]+1
            }
        }

        cls
        $CheckedUsers = $CheckedUsers + 1
        Write-Host Checked $CheckedUsers out of $TotalUsers ...
    }

    foreach ($key in $attributesHash.Keys)
    {
        If($attributesHash[$key] -eq 0){
            Write-Host $attributesHash[$key] times the attribute $key is used ***Unused Found***
            ($attributesHash[$key].ToString()+" times the attribute $key is used ***Unused Found***") | Out-File -FilePath $FilePath -Append
        }
        else
        {
            Write-Host $attributesHash[$key] times the attribute $key is used.
            ($attributesHash[$key].ToString()+" times the attribute $key is used.") | Out-File -FilePath $FilePath -Append
        }
    }
}

Function Is-InUse ([string]$value)
{
    if (($value -eq $Null) -or ($value.Length -eq 0))
    {
        return $False
    }
    return $True
}

Write-Host
Write-Host "Schema Naming Context == $($SchemaDn)" -ForegroundColor Yellow
Write-Host "Domain Naming Context == $($BaseDn)" -ForegroundColor Yellow
Write-Host "LDAP Server == $($RootDsn.dnsHostName)" -ForegroundColor Yellow
Write-Host

$c = Read-Host "Do you want to continue: Y/N"

if (($c.ToLower() -eq "y") -or ($c.ToLower() -eq "yes"))
{
    Find-AllUnused-New
}