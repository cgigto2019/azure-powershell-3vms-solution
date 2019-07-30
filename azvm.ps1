# ./azvm.ps1 <number> <resource group name>
param([int]$nbVM,[string]$resourceGroup)
New-AzResourceGroup -Name $resourceGroup -Location "EastUS"

For ($i = 1; $i -le $nbVM; $i++)
{
  $vmName = "$resourceGroup" + $i
  $subnetName = "$resourceGroup" + $i
  $vnetName = "$resourceGroup" + $i
  $pipName = "$resourceGroup" + $i
  $sgName = "$resourceGroup" + $i
  $nicName = "$resourceGroup" + $i

  Write-Host "Creating VM: " $vmName

  # Create a subnet configuration

  $subnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix 192.168.1.0/24

  # Create a virtual network
  $vnet = New-AzVirtualNetwork `
    -ResourceGroupName $resourceGroup `
    -Location "EastUS" `
    -Name $vnetName `
    -AddressPrefix 192.168.0.0/16 `
    -Subnet $subnetConfig

  # Create a public IP address and specify a DNS name
  $pip = New-AzPublicIpAddress `
    -ResourceGroupName $resourceGroup `
    -Location "EastUS" `
    -AllocationMethod Static `
    -IdleTimeoutInMinutes 4 `
    -Name $pipName

  # Create an inbound network security group rule for port 22
  $nsgRuleSSH = New-AzNetworkSecurityRuleConfig `
    -Name "myNetworkSecurityGroupRuleSSH"  `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -Priority 1000 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 22 `
    -Access "Allow"

  # Create an inbound network security group rule for port 80
  $nsgRuleHTTP = New-AzNetworkSecurityRuleConfig `
    -Name "myNetworkSecurityGroupRuleHTTP"  `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -Priority 1001 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 80 `
    -Access "Allow"

  # Create an inbound network security group rule for port 443
  $nsgRuleHTTPS = New-AzNetworkSecurityRuleConfig `
    -Name "myNetworkSecurityGroupRuleHTTPS"  `
    -Protocol "Tcp" `
    -Direction "Inbound" `
    -Priority 1002 `
    -SourceAddressPrefix * `
    -SourcePortRange * `
    -DestinationAddressPrefix * `
    -DestinationPortRange 443 `
    -Access "Allow"

  # Create a network security group
  $nsg = New-AzNetworkSecurityGroup `
    -ResourceGroupName $resourceGroup `
    -Location "EastUS" `
    -Name $sgName `
    -SecurityRules $nsgRuleSSH,$nsgRuleHTTP,$nsgRuleHTTPS

  # Create a virtual network card and associate with public IP address and NSG
  $nic = New-AzNetworkInterface `
    -Name $nicName `
    -ResourceGroupName $resourceGroup `
    -Location "EastUS" `
    -SubnetId $vnet.Subnets[0].Id `
    -PublicIpAddressId $pip.Id `
    -NetworkSecurityGroupId $nsg.Id

  # Define a credential object
  $securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
  $cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

  # Create a virtual machine configuration
  $vmConfig = New-AzVMConfig `
    -VMName $vmName `
    -VMSize "Standard_DS1" | `
  Set-AzVMOperatingSystem `
    -Linux `
    -ComputerName $vmName `
    -Credential $cred `
    -DisablePasswordAuthentication | `
  Set-AzVMSourceImage `
    -PublisherName "Canonical" `
    -Offer "UbuntuServer" `
    -Skus "18.04-LTS" `
    -Version "latest" | `
  Add-AzVMNetworkInterface `
    -Id $nic.Id

  # Configure the SSH key
  $sshPublicKey = cat ~/.ssh/id_rsa.pub
  Add-AzVMSshPublicKey `
    -VM $vmconfig `
    -KeyData $sshPublicKey `
    -Path "/home/azureuser/.ssh/authorized_keys"

  # Create the Virtual Machine
  New-AzVM `
  -ResourceGroupName $resourceGroup `
  -Location eastus -VM $vmConfig

  $pipaddress = (Get-AzPublicIpAddress -ResourceGroupName $resourceGroup | Select "IpAddress")
  $n = $i + 3
  $serveraddress = ($pipaddress | sed -n "$n p")

  ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no azureuser@$serveraddress "sudo apt update && sudo apt -y install git && git clone https://github.com/cgigto2019/auto-wordpress && cd auto-wordpress && sudo bash -x ./wordpress.sh"
  Write-Host "Please connect with ssh azureuser@$serveraddress or visit https://www.$serveraddress.nip.io/"
}
