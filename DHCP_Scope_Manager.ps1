<#
.SYNOPSIS
  Name: DHCP_Scope_Manager.ps1
  The purpose of this script is to easily manage often used tasks
  in an DHCP Scope on a Windows server without the need of GUI.
.DESCRIPTION
  This scipt is ment to run directly on the HDCP server to manage
  an HDCP scope as an alternative to the default DHCP GUI interface.
  The biggest advantage is the ability to search rather than look
  in lists for specific IP addresses or Client IDs.
  Currently only supports IPv4.
  The DhcpServer module is required for this script to run.
.NOTES
  Original release Date: 10.07.2018
  Author: Flemming Sørvollen Skaret (https://github.com/flemmingss/)
.LINK
  https://github.com/flemmingss/
  #>

$firstrun = $true

function import_module # Check for, and load DhcpServer module
{

    try
    {
    Import-Module -Name DhcpServer
    }

    catch
    {
    Write-Host ERROR: Unable to import module DhcpServer  -ForegroundColor Red
    read-host “Press ENTER to exit...”
    exit
    }

}

function window_title #Change the title of the command Windows
{
$host.ui.RawUI.WindowTitle = "DHCP Scope Manager - Selected Scope: [$SelectedScope_ScopeID] $script:SelectedScope_Name" #Window title
}

function select_scope #Select a Scope to manage
{
$SelectedScope = Read-Host "Select ScopeID"

    try
    {
    $script:SelectedScope_ScopeID = (Get-DhcpServerv4Scope -ScopeId $SelectedScope).ScopeId.IPAddressToString
    $script:SelectedScope_Name = (Get-DhcpServerv4Scope -ScopeId $SelectedScope).Name
    $script:SelectedScope_Description = (Get-DhcpServerv4Scope -ScopeId $SelectedScope).Description
    $script:SelectedScope_SubnetMask = (Get-DhcpServerv4Scope -ScopeId $SelectedScope).SubnetMask.IPAddressToString
    $script:SelectedScope_StartRange = (Get-DhcpServerv4Scope -ScopeId $SelectedScope).StartRange.IPAddressToString
    $script:SelectedScope_EndRange = (Get-DhcpServerv4Scope -ScopeId $SelectedScope).EndRange.IPAddressToString
    $script:SelectedScope_State = (Get-DhcpServerv4Scope -ScopeId $SelectedScope).State
    $local:SelectedScope_AddressesInUse = (Get-DhcpServerv4ScopeStatistics -ScopeId $SelectedScope).AddressesInUse
    $local:SelectedScope_PercentageInUse = (Get-DhcpServerv4ScopeStatistics -ScopeId $SelectedScope).PercentageInUse
    $script:ValidScope = $true

    Write-Host "Scope [$SelectedScope_ScopeID] $SelectedScope_Name Selected" -ForegroundColor Green
    Write-Host "IP Range: $SelectedScope_StartRange - $SelectedScope_EndRange" -ForegroundColor Yellow
    Write-Host "Subnet Mask: $SelectedScope_SubnetMask" -ForegroundColor Yellow
    Write-Host "Addresses in use:" $SelectedScope_AddressesInUse - $SelectedScope_PercentageInUse -NoNewline -ForegroundColor Yellow
    Write-Host "%" -ForegroundColor Yellow

    }

    catch
    {
    Write-Host "Unable to select Scope" -ForegroundColor Red
    $script:ValidScope = $false

    $script:SelectedScope_ScopeID = $null
    $script:SelectedScope_Name = $null
    $script:SelectedScope_Description = $null
    $script:SelectedScope_SubnetMask = $null
    $script:SelectedScope_StartRange = $null
    $script:SelectedScope_EndRange = $null
    $script:SelectedScope_State = $null
    }

    finally
    {
    window_title

        if ($ValidScope)
        {
        display_menu
        }

        else
        {
        select_scope
        }

    }

}

function replicate_scope #Replicate the selected scope to failover server
{

    try
    {
    Invoke-DhcpServerv4FailoverReplication -ScopeId $SelectedScope_ScopeID -Force | Out-Null
    $PartnerServer = (Get-DhcpServerv4Failover).partnerserver
    Write-Host "Scope $SelectedScope_ScopeID replicated successfully to failover server $PartnerServer" -ForegroundColor Green
    }

    catch
    {
    Write-Host "An error occurred during replication" -ForegroundColor Red
    }

    finally
    {
    display_menu
    }

}

function list_free_ipaddress #List all free IP addresses in the scope
{

    try
    {

        if ((Get-DhcpServerv4ScopeStatistics -ScopeId $SelectedScope_ScopeID).free -eq 0)
        {
        Write-Host "There are no available IP addresses in this scope" -ForegroundColor yellow
        }

        else
        {
        Get-DhcpServerv4FreeIPAddress -ScopeId $SelectedScope_ScopeID -NumAddress (Get-DhcpServerv4ScopeStatistics -ScopeId $SelectedScope_ScopeID).Free
        }

    }

    catch
    {
    Write-Host "Aan error occurred" -ForegroundColor Red
    }

    finally
    {
    display_menu
    }

}

function list_active_unreserved_ipaddress #List all active, but not reserved IP addresses in the scope
{

    try
    {
    $result = Get-DhcpServerv4Lease -ScopeId $SelectedScope_ScopeID -AllLeases | Where-Object -Property AddressState -eq Active | Select-Object IPAddress,ClientID
    
        if ($local:result -eq $null)
        {
        Write-Host "There are no actve unreserved IP addresses in this scope" -ForegroundColor yellow
        }
    
        else
        {
        $local:result
        }

    }

    catch
    {
    Write-Host "Aan error occurred" -ForegroundColor Red
    }

    finally
    {
    display_menu
    }

}

function list_active_reserved_ipaddress #List all active IP addresses that are reserved in the scope
{

    try
    {
    $result = Get-DhcpServerv4Lease -ScopeId $SelectedScope_ScopeID -AllLeases | Where-Object -Property AddressState -eq ActiveReservation | Select-Object IPAddress,ClientID
    
        if ($local:result -eq $null)
        {
        Write-Host "There are no actve reserved IP addresses in this scope" -ForegroundColor yellow
        }
    
        else
        {
        $local:result
        }

    }

    catch
    {
    Write-Host "Aan error occurred" -ForegroundColor Red
    }

    finally
    {
    display_menu
    }

}

function list_inactive_reserved_ipaddress #List all inactive IP addresses that are reserved in the scope
{

    try
    {
    $result = Get-DhcpServerv4Lease -ScopeId $SelectedScope_ScopeID -AllLeases | Where-Object -Property AddressState -eq InactiveReservation | Select-Object IPAddress,ClientID
    
        if ($local:result -eq $null)
        {
        Write-Host "There are no inactive reserved IP addresses in this scope" -ForegroundColor yellow
        }
    
        else
        {
        $local:result
        }

    }

    catch
    {
    Write-Host "Aan error occurred" -ForegroundColor Red
    }

    finally
    {
    display_menu
    }

}

function reserve_ipaddress #Reserve an IP address in this scope
{
$IPAddress_suggestion = $null #suggest only if there are at least 0 free address

    if ((Get-DhcpServerv4ScopeStatistics -ScopeId $SelectedScope_ScopeID).free -ne 0)
    {

        try
        {
        $FreeIP = (Get-DhcpServerv4FreeIPAddress -ScopeId $SelectedScope_ScopeID)
        $IPAddress_suggestion = " (e.g. the free IP $FreeIP)"
        }
    
        catch
        {    
        }

    }

$IPAddress = Read-Host "Select a IP address$IPAddress_suggestion in the scopes range $SelectedScope_StartRange - $SelectedScope_EndRange"
$ClientId =  Read-Host "Select a ClientID (MAC) for $IPAddress"

    try
    {
    Add-DhcpServerv4Reservation -ScopeId $SelectedScope_ScopeID -IPAddress $IPAddress -ClientId $ClientId
    Write-Host "The IP address $IPAddress was successfully reserved for $ClientId." -ForegroundColor Green
    }

    catch
    {
    Write-Host "Aan error occurred, make sure that the IP and MAC address are free and valid" -ForegroundColor Red
    }

    finally
    {
    display_menu
    }

}

function remove_ipadress_reservation #Remove IP address reservation by IP-address
{
$IPAddress = Read-Host "Select a IP address in the scope to delete the reservation for"

    try
    {
    $ReservationtoDelete_IP = (Get-DhcpServerv4Reservation -IPAddress $IPAddress).IPAddress.IPAddressToString
    $ReservationtoDelete_ScopeID = (Get-DhcpServerv4Reservation -IPAddress $IPAddress).ScopeId.IPAddressToString
    $ReservationtoDelete_ClientID = (Get-DhcpServerv4Reservation -IPAddress $IPAddress).ClientID


        if ($SelectedScope_ScopeID -eq $ReservationtoDelete_ScopeID) #check if the IP is in this scope
        {

            try
            {
            Remove-DhcpServerv4Reservation -IPAddress $ReservationtoDelete_IP
            Write-Host "The reservation of $ReservationtoDelete_IP are successfully removed from $ReservationtoDelete_ClientID" -ForegroundColor Green #Success
            }
            
            catch
            {
            Write-Host "Error: Uable to delete the reservation" -ForegroundColor Red #Error
            }

        }
        
        else
        {
        Write-Host "The selected IP-address are not found inside the selected scope" -ForegroundColor Yellow #IP exist, but not in this scope
        }

    }
    
    catch
    {
    Write-Host "The selected IP-address are not found on this DHCP server" -ForegroundColor Yellow #IP don't exist on server
    }

display_menu
}

function remove_ipadress_reservation_by_clientid #Remove IP address reservation by ClientID
{
$ClientID = Read-Host "Select a ClientID (MAC) address in the scope to delete the reservation for"

    try
    {
    $ReservationtoDelete_IP = (Get-DhcpServerv4Reservation -ScopeId $SelectedScope_ScopeID -ClientId $ClientID).IPAddress.IPAddressToString                               
    $ReservationtoDelete_ScopeID = (Get-DhcpServerv4Reservation -ScopeId $SelectedScope_ScopeID -ClientId $ClientID).ScopeId.IPAddressToString
    $ReservationtoDelete_ClientID = (Get-DhcpServerv4Reservation -ScopeId $SelectedScope_ScopeID -ClientId $ClientID).ClientID

        try
        {
        Remove-DhcpServerv4Reservation -IPAddress $ReservationtoDelete_IP
        Write-Host "The reservation of $ReservationtoDelete_IP are successfully removed from $ReservationtoDelete_ClientID" -ForegroundColor Green #Success
        }
            
        catch
        {
        Write-Host "Error: Uable to delete the reservation" -ForegroundColor Red #Error
        }

    }
    
    catch
    {
    Write-Host "The selected ClientID are not found in this Scope" -ForegroundColor Yellow #IP don't exist in Scope
    }

    finally
    {
    display_menu
    }

}

function get_lease_by_clientid #Find IP leaes by Client ID
{
$ClientID = Read-Host "Select a ClientID (MAC) address in this scope som find related lease"

    try
    {
    Get-DhcpServerv4Lease -ScopeId $SelectedScope_ScopeID -ClientId $ClientID | Select-Object IPAddress,ClientID,AddressState
    }

    catch
    {
    Write-Host "No leases for the specified ClientID found in this scope" -ForegroundColor Yellow
    }

    finally
    {
    display_menu
    }

}

function get_lease_by_ip #Find IP lease by IP Address
{
$IPAddress = Read-Host "Select an IP address in this scope som find related lease"

    try
    {
    $result = Get-DhcpServerv4Lease -IPAddress $IPAddress | Where-Object ScopeId -EQ $SelectedScope_ScopeID
    
        if ($local:result -ne $null)
        {
        $result | Select-Object IPAddress,ClientID,AddressState
        }
   
    }

    catch
    {    
    Write-Host "No leases for the specified IP found in this scope" -ForegroundColor Yellow
    }

    finally
    {
    display_menu
    }

}

function display_menu #Display the user menu
{
window_title

    if ($firstrun -ne $true)
    {
    read-host “Press ENTER to continue to menu...”
    }

$firstrun = $false

Write-Host "+-------------------------------------------------------+" -ForegroundColor Magenta
Write-Host " 0 - Exit"
Write-Host " 1 - Select a New Scope"
Write-Host " 2 - Replicate Scope"
Write-Host " 3 - List all free IP addresses"
Write-Host " 4 - List all active IP addresses which is not reserved"
Write-Host " 5 - List all active IP addresses which is reserved"
Write-Host " 6 - List all inactive IP addresses which is reserved"
Write-Host " 7 - Reserve IP address"
Write-Host " 8 - Remove reservation by IP"
Write-Host " 9 - Remove reservation by ClientID"
Write-Host " 10 - Find Lease by ClientID"
Write-Host " 11 - Find Lease by IP"
Write-Host "+-------------------------------------------------------+" -ForegroundColor Magenta

$menu_choice = Read-Host "Select alternative"

    if ($menu_choice -eq "0")
    {
    exit
    }

    if ($menu_choice -eq "1")
    {
    select_scope
    }

    if ($menu_choice -eq "2")
    {
    replicate_scope
    }
    
    if ($menu_choice -eq "3")
    {
    list_free_ipaddress
    }
    
    if ($menu_choice -eq "4")
    {
    list_active_unreserved_ipaddress
    }
    
    if ($menu_choice -eq "5")
    {
    list_active_reserved_ipaddress
    }
    
    if ($menu_choice -eq "6")
    {
    list_inactive_reserved_ipaddress
    }
    
    if ($menu_choice -eq "7")
    {
    reserve_ipaddress
    
    }
    if ($menu_choice -eq "8")
    {
    remove_ipadress_reservation
    }
    
    if ($menu_choice -eq "9")
    {
    remove_ipadress_reservation_by_clientid
    }

    if ($menu_choice -eq "10")
    {
    get_lease_by_clientid
    }

    if ($menu_choice -eq "11")
    {
    get_lease_by_ip
    }

    else
    {
    Write-Host "Invalid choice" -ForegroundColor Red
    display_menu
    }

}

# First Run:
$ErrorActionPreference = "Stop" #Make all errors terminating
$SelectedScope_ScopeID = $null
$script:SelectedScope_Name = $null
window_title
import_module
select_scope

# End for Script
