#PowerNSX IPSet Tests.
#Nick Bradford : nbradford@vmware.com

#Because PowerNSX is an API consumption tool, its test framework is limited to
#exercising cmdlet functionality against a functional NSX and vSphere API
#If you disagree with this approach - feel free to start writing mocks for all
#potential API reponses... :)

#In the meantime, the test format is not as elegant as normal TDD, but Ive made some effort to get close to this.
#Each functional area in NSX should have a separate test file.

#Try to group related tests in contexts.  Especially ones that rely on configuration done in previous tests
#Try to make tests as standalone as possible, but generally round trips to the API are expensive, so bear in mind
#the time spent recreating configuration created in previous tests just for the sake of keeping test isolation.

#Try to put all non test related setup and tear down in the BeforeAll and AfterAll sections.  ]
#If a failure in here occurs, the Describe block is not executed.

#########################
#Do not remove this - we need to ensure connection setup and module deps preload have occured.
If ( -not $PNSXTestVC ) {
    Throw "Tests must be invoked via Start-Test function from the Test module.  Import the Test module and run Start-Test"
}

Describe "IPSets" {

    BeforeAll {

        #BeforeAll block runs _once_ at invocation regardless of number of tests/contexts/describes.
        #We load the mod and establish connection to NSX Manager here.

        #Put any setup tasks in here that are required to perform your tests.  Typical defaults:
        import-module $pnsxmodule
        $script:DefaultNsxConnection = Connect-NsxServer -vCenterServer $PNSXTestVC -Credential $PNSXTestDefViCred
        #Put any script scope variables you need to reference in your tests.
        #For naming items that will be created in NSX, use a unique prefix
        #pester_<testabbreviation>_<objecttype><uid>.  example:
        $script:IpSetPrefix = "pester_ipset_"

        #Clean up any existing ipsets from previous runs...
        get-nsxipset | ? { $_.name -match $IpSetPrefix } | remove-nsxipset -confirm:$false


    }

    AfterAll {
        #AfterAll block runs _once_ at completion of invocation regardless of number of tests/contexts/describes.
        #Clean up anything you create in here.  Be forceful - you want to leave the test env as you found it as much as is possible.
        #We kill the connection to NSX Manager here.

        get-nsxipset | ? { $_.name -match $IpSetPrefix } | remove-nsxipset -confirm:$false

        disconnect-nsxserver
    }

    Context "IpSet retrieval" {
        BeforeAll {
            $script:ipsetName = "$IpSetPrefix-get"
            $ipSetDesc = "PowerNSX Pester Test get ipset"
            $script:ipsetNameUniversal = "$IpSetPrefix-get-universal"
            $ipSetDescUniversal = "PowerNSX Pester Test get universal ipset"
            $script:get = New-nsxipset -Name $ipsetName -Description $ipSetDesc
            $script:getuniversal = New-nsxipset -Name $ipsetNameUniversal -Description $ipSetDescUniversal -Universal
        }

        it "Can retrieve an ipset by name" {
            {Get-nsxipset -Name $ipsetName} | should not throw
            $ipset = Get-nsxipset -Name $ipsetName
            $ipset | should not be $null
            $ipset.name | should be $ipsetName
         }

        it "Can retrieve an ipset by id" {
            {Get-nsxipset -objectId $get.objectId } | should not throw
            $ipset = Get-nsxipset -objectId $get.objectId
            $ipset | should not be $null
            $ipset.objectId | should be $get.objectId
         }

         It "Can retrieve both universal and global IpSets" {
            $ipsets = Get-NsxIpSet
            ($ipsets | ? { $_.isUniversal -eq 'True'} | measure).count | should begreaterthan 0
            ($ipsets | ? { $_.isUniversal -eq 'False'} | measure).count | should begreaterthan 0
         }

         It "Can retrieve universal only IpSets" {
            $ipsets = Get-NsxIpSet -UniversalOnly
            ($ipsets | ? { $_.isUniversal -eq 'True'} | measure).count | should begreaterthan 0
            ($ipsets | ? { $_.isUniversal -eq 'False'} | measure).count | should be 0
         }

         It "Can retrieve local only IpSets" {
            $ipsets = Get-NsxIpSet -LocalOnly
            ($ipsets | ? { $_.isUniversal -eq 'True'} | measure).count | should be 0
            ($ipsets | ? { $_.isUniversal -eq 'False'} | measure).count | should begreaterthan 0
         }
    }

    Context "Successful IpSet Creation" {

        AfterAll {
            get-nsxipset | ? { $_.name -match $IpSetPrefix } | remove-nsxipset -confirm:$false
        }

        it "Can create an ipset with single address" {

            $ipsetName = "$IpSetPrefix-ipset-create1"
            $ipsetDesc = "PowerNSX Pester Test create ipset"
            $ipaddresses = "1.2.3.4"
            $ipset = New-nsxipset -Name $ipsetName -Description $ipsetDesc -IPAddresses $ipaddresses
            $ipset.Name | Should be $ipsetName
            $ipset.Description | should be $ipsetDesc
            $get = Get-nsxipset -Name $ipsetName
            $get.name | should be $ipset.name
            $get.description | should be $ipset.description
            $get.value | should be $ipset.value
            $get.inheritanceAllowed | should be "false"
        }

        it "Can create an ipset with range" {

            $ipsetName = "$IpSetPrefix-ipset-create2"
            $ipsetDesc = "PowerNSX Pester Test create ipset"
            $ipaddresses = "1.2.3.4-2.3.4.5"
            $ipset = New-nsxipset -Name $ipsetName -Description $ipsetDesc -IPAddresses $ipaddresses
            $ipset.Name | Should be $ipsetName
            $ipset.Description | should be $ipsetDesc
            $get = Get-nsxipset -Name $ipsetName
            $get.name | should be $ipset.name
            $get.description | should be $ipset.description
            $get.value | should be $ipset.value
            $get.inheritanceAllowed | should be "false"
        }

        it "Can create an ipset with CIDR" {

            $ipsetName = "$IpSetPrefix-ipset-create3"
            $ipsetDesc = "PowerNSX Pester Test create ipset"
            $ipaddresses = "1.2.3.0/24"
            $ipset = New-nsxipset -Name $ipsetName -Description $ipsetDesc -IPAddresses $ipaddresses
            $ipset.Name | Should be $ipsetName
            $ipset.Description | should be $ipsetDesc
            $get = Get-nsxipset -Name $ipsetName
            $get.name | should be $ipset.name
            $get.description | should be $ipset.description
            $get.value | should be $ipset.value
            $get.inheritanceAllowed | should be "false"
        }

        it "Can create an ipset with inheritance enabled" {

            $ipsetName = "$IpSetPrefix-ipset-create4"
            $ipsetDesc = "PowerNSX Pester Test create ipset"
            $ipaddresses = "1.2.3.4"
            $ipset = New-nsxipset -Name $ipsetName -Description $ipsetDesc -IPAddresses $ipaddresses -EnableInheritance
            $ipset.Name | Should be $ipsetName
            $ipset.Description | should be $ipsetDesc
            $get = Get-nsxipset -Name $ipsetName
            $get.name | should be $ipset.name
            $get.description | should be $ipset.description
            $get.value | should be $ipset.value
            $get.inheritanceAllowed | should be "true"
        }

        it "Can create an ipset and return an objectId only" {
            $ipsetName = "$IpSetPrefix-objonly-1234"
            $ipsetDesc = "PowerNSX Pester Test objectidonly ipset"
            $ipaddresses = "1.2.3.4"
            $id = New-nsxipset -Name $ipsetName -Description $ipsetDesc -IPAddresses $ipaddresses -ReturnObjectIdOnly
            $id | should BeOfType System.String
            $id | should match "^ipset-\d*$"
         }
    }

    Context "Unsuccessful IpSet Creation" {

        it "Fails to create an ipset with invalid address" {

            $ipsetName = "$IpSetPrefix-ipset-create1"
            $ipsetDesc = "PowerNSX Pester Test create ipset"
            $ipaddresses = "1.2.3.4.5"
            { New-nsxipset -Name $ipsetName -Description $ipsetDesc -IPAddresses $ipaddresses } | should throw
        }
    }


    Context "IpSet Deletion" {

        BeforeEach {
            $ipsetName = "$IpSetPrefix-delete"
            $ipsetDesc = "PowerNSX Pester Test delete IpSet"
            $script:delete = New-nsxipset -Name $ipsetName -Description $ipsetDesc

        }

        it "Can delete an ipset by object" {

            $delete | Remove-nsxipset -confirm:$false
            {Get-nsxipset -objectId $delete.objectId} | should throw
        }

    }

    Context "IpSet Modification - Addition" {

        BeforeEach {
            $ipsetName = "$IpSetPrefix-modify"
            $ipsetDesc = "PowerNSX Pester Test modify IpSet"
            get-nsxipset $ipsetName | remove-nsxipset -Confirm:$false
            $script:modify = New-nsxipset -Name $ipsetName -Description $ipsetDesc

        }

        AfterEach {
            $ipsetName = "$IpSetPrefix-modify"
            get-nsxipset $ipsetName | remove-nsxipset -Confirm:$false

        }

        it "Can add a new address to an ip set" {
            $IpAddress = "1.2.3.4"
            $ipset = $modify | Add-NsxIpSetMember -IpAddress $IpAddress
            $ipset.value | should be $IpAddress
        }

        it "Fails to add a duplicate address to an ip set" {
            $IpAddress = "1.2.3.4"
            $ipset = $modify | Add-NsxIpSetMember -IpAddress $IpAddress
            $ipset.value | should be $IpAddress
            {$ipset | Add-NsxIpSetMember -IpAddress $IpAddress} | should throw
        }

        it "Can add a new range to an ip set" {
            $IpAddress = "1.2.3.4-2.3.4.5"
            $ipset = $modify | Add-NsxIpSetMember -IpAddress $IpAddress
            $ipset.value | should be $IpAddress
        }

        it "Can add a new cidr to an ip set" {
            $IpAddress = "1.2.3.0/24"
            $ipset = $modify | Add-NsxIpSetMember -IpAddress $IpAddress
            $ipset.value | should be $IpAddress
        }

        it "Can add multiple values to an ip set" {
            $IpAddress1 = "1.2.3.4"
            $IpAddress2 = "4.3.2.1"
            $ipset = $modify | Add-NsxIpSetMember -IpAddress $IpAddress1,$ipaddress2
            $ipset.value -split "," -contains $ipAddress1 | should be $true
            $ipset.value -split "," -contains $ipAddress2 | should be $true
        }
    }
    Context "IpSet Modification - Removal" {

        BeforeEach {
            $ipsetName = "$IpSetPrefix-removal"
            $ipsetDesc = "PowerNSX Pester Test removal IpSet"
            $ipaddress = "1.2.3.4"
            $iprange = "1.2.3.4-2.3.4.5"
            $cidr = "1.2.3.0/24"
            get-nsxipset $ipsetName | remove-nsxipset -Confirm:$false
            $script:remove = New-nsxipset -Name $ipsetName -Description $ipsetDesc -IPAddresses "$ipaddress,$iprange,$cidr"

        }

        AfterEach {
            $ipsetName = "$IpSetPrefix-removal"
            get-nsxipset $ipsetName | remove-nsxipset -Confirm:$false

        }

        it "Can remove an address from an ip set" {
            $ipset = $remove | Remove-NsxIpSetMember -IpAddress $IpAddress
            $ipset.value -split "," -contains $ipaddress | should be $false
            $ipset.value -split "," -contains $iprange | should be $true
            $ipset.value -split "," -contains $cidr | should be $true
        }

        it "Can remove a range from an ip set" {
            $ipset = $remove | Remove-NsxIpSetMember -IpAddress $iprange
            $ipset.value -split "," -contains $iprange | should be $false
            $ipset.value -split "," -contains $ipaddress | should be $true
            $ipset.value -split "," -contains $cidr | should be $true
        }

        it "Can remove a cidr from an ip set" {
            $ipset = $remove | Remove-NsxIpSetMember -IpAddress $cidr
            $ipset.value -split "," -contains $cidr | should be $false
            $ipset.value -split "," -contains $ipaddress | should be $true
            $ipset.value -split "," -contains $iprange | should be $true
        }

        it "Can remove multiple values from an ip set" {

            $ipset = $remove | Remove-NsxIpSetMember -IpAddress $ipaddress,$iprange
            $ipset.value -split "," -contains $ipaddress | should be $false
            $ipset.value -split "," -contains $iprange | should be $false
            $ipset.value -split "," -contains $cidr | should be $true
        }


    }
}