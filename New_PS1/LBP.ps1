function Get-SecureBootStoreCertificates {
    [CmdletBinding()]
    param(
        # Stores principaux
        [string[]]$Name = @('PK','KEK','db','dbx'),

        # Ajoute PKDefault, KEKDefault, dbDefault, dbxDefault, dbt, dbtDefault si présents
        [switch]$IncludeDefaults,

        # Inclut aussi les entrées hash (souvent dans dbx)
        [switch]$IncludeHashes
    )

    # GUIDs de type d'entrée ESL
    $EFI_CERT_X509_GUID   = [Guid]'a5c059a1-94e4-4aa7-87b5-ab155c2bf072'
    $EFI_CERT_SHA256_GUID = [Guid]'c1c41626-504c-4092-aca9-41f936934328'
    $EFI_CERT_SHA1_GUID   = [Guid]'826ca512-cf10-4ac9-b187-be01496631bd'

    function ConvertFrom-EfiSignatureList {
        param(
            [Parameter(Mandatory=$true)][byte[]]$Bytes,
            [Parameter(Mandatory=$true)][string]$StoreName,
            [switch]$IncludeHashes
        )

        $results = New-Object System.Collections.Generic.List[object]

        # PS 5.1 friendly: on évite [MemoryStream]::new(,$Bytes)
        $ms = New-Object System.IO.MemoryStream
        $ms.Write($Bytes, 0, $Bytes.Length) | Out-Null
        $ms.Position = 0
        $br = New-Object System.IO.BinaryReader($ms)

        try {
            while ($br.BaseStream.Position -lt $br.BaseStream.Length) {

                # Il faut au moins 28 bytes (header ESL)
                if (($br.BaseStream.Length - $br.BaseStream.Position) -lt 28) { break }

                $listStartPos   = $br.BaseStream.Position

                $sigTypeBytes   = $br.ReadBytes(16)
                $listSize       = $br.ReadUInt32()
                $headerSize     = $br.ReadUInt32()
                $sigSize        = $br.ReadUInt32()

                # Sanity checks
                if ($listSize -lt 28) { break }
                if ($sigSize -lt 16) { break }

                $listEndPos = $listStartPos + $listSize
                if ($listEndPos -gt $br.BaseStream.Length) { break }

                $sigTypeGuid = [Guid]::new($sigTypeBytes)

                # Skip SignatureHeader
                if ($headerSize -gt 0) {
                    $null = $br.ReadBytes($headerSize)
                }

                $bytesForEntries = $listEndPos - $br.BaseStream.Position
                if ($bytesForEntries -lt $sigSize) {
                    # Pas d'entrée, on saute à la fin de la liste
                    $br.BaseStream.Position = $listEndPos
                    continue
                }

                $entryCount = [Math]::Floor($bytesForEntries / $sigSize)

                for ($i = 0; $i -lt $entryCount; $i++) {
                    $ownerGuidBytes = $br.ReadBytes(16)
                    if ($ownerGuidBytes.Length -ne 16) { break }

                    $ownerGuid = [Guid]::new($ownerGuidBytes)

                    $dataLen = $sigSize - 16
                    $sigData = $br.ReadBytes($dataLen)
                    if ($sigData.Length -ne $dataLen) { break }

                    if ($sigTypeGuid -eq $EFI_CERT_X509_GUID) {
                        try {
                            $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @(,$sigData)

                            $results.Add([pscustomobject]@{
                                Store         = $StoreName
                                EntryType     = 'X509'
                                SignatureType = $sigTypeGuid
                                Owner         = $ownerGuid
                                Subject       = $cert.Subject
                                Issuer        = $cert.Issuer
                                NotBefore     = $cert.NotBefore
                                NotAfter      = $cert.NotAfter
                                Thumbprint    = $cert.Thumbprint
                                SerialNumber  = $cert.SerialNumber
                                Certificate   = $cert
                            })
                        }
                        catch {
                            $results.Add([pscustomobject]@{
                                Store         = $StoreName
                                EntryType     = 'X509-Invalid'
                                SignatureType = $sigTypeGuid
                                Owner         = $ownerGuid
                                DataLength    = $sigData.Length
                                Error         = $_.Exception.Message
                            })
                        }
                    }
                    elseif ($IncludeHashes -and ($sigTypeGuid -eq $EFI_CERT_SHA256_GUID -or $sigTypeGuid -eq $EFI_CERT_SHA1_GUID)) {
                        $hashAlg = if ($sigTypeGuid -eq $EFI_CERT_SHA256_GUID) { 'SHA256' } else { 'SHA1' }
                        $hex = ($sigData | ForEach-Object { $_.ToString('X2') }) -join ''

                        $results.Add([pscustomobject]@{
                            Store         = $StoreName
                            EntryType     = "Hash-$hashAlg"
                            SignatureType = $sigTypeGuid
                            Owner         = $ownerGuid
                            HashHex       = $hex
                            DataLength    = $sigData.Length
                        })
                    }
                    elseif ($IncludeHashes) {
                        $hex = ($sigData | ForEach-Object { $_.ToString('X2') }) -join ''
                        $results.Add([pscustomobject]@{
                            Store         = $StoreName
                            EntryType     = 'Unknown'
                            SignatureType = $sigTypeGuid
                            Owner         = $ownerGuid
                            DataLength    = $sigData.Length
                            DataHex       = $hex
                        })
                    }
                }

                # On se repositionne à la fin exacte de la liste
                $br.BaseStream.Position = $listEndPos
            }
        }
        finally {
            $br.Close()
            $ms.Close()
        }

        return $results
    }

    # Construire la liste finale des stores
    $stores = @()
    $stores += $Name

    if ($IncludeDefaults) {
        $stores += @('PKDefault','KEKDefault','dbDefault','dbxDefault','dbt','dbtDefault')
    }

    foreach ($store in ($stores | Select-Object -Unique)) {
        try {
            $v = Get-SecureBootUEFI -Name $store -ErrorAction Stop

            if (-not $v.Bytes -or $v.Bytes.Count -eq 0) { continue }

            # Force conversion en byte[]
            [byte[]]$raw = $v.Bytes

            ConvertFrom-EfiSignatureList -Bytes $raw -StoreName $store -IncludeHashes:$IncludeHashes
        }
        catch {
            Write-Verbose "Skip '$store' : $($_.Exception.Message)"
        }
    }
}