# Charger l'interface XAML
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
$path = "$PSScriptRoot\\interface1.xml"
[string]$xamlContent = Get-Content -Path $path -Raw -Encoding UTF8
$reader = New-Object System.IO.StringReader $xamlContent
$xmlReader = [System.Xml.XmlReader]::Create($reader)
$Global:interface = [Windows.Markup.XamlReader]::Load($xmlReader)

# Fonction pour écrire les erreurs dans le fichier de log
function Log-Error {
 param (
 [string]$message,
 [string]$ticketNumber
 )
 $logFilePath = "\\chemin\\vers\\logs\\error_log_$ticketNumber.txt"
 Add-Content -Path $logFilePath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
}

# Fonction pour écrire les informations dans le fichier de log
function Log-Info {
 param (
 [string]$message,
 [string]$ticketNumber
 )
 $logFilePath = "\\chemin\\vers\\logs\\log_$ticketNumber.txt"
 Add-Content -Path $logFilePath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $message"
}

# Afficher l'interface et définir les variables pour les éléments nommés
$Global:txtWorkorder = $Global:interface.FindName("txtWorkorder")
$Global:textboxSearchUser = $Global:interface.FindName("textboxSearchUser")
$Global:buttonSearchUser = $Global:interface.FindName("buttonSearchUser")
$Global:textboxNAS = $Global:interface.FindName("textboxNAS")
$Global:textboxCOM = $Global:interface.FindName("textboxCOM")
$Global:textboxPath = $Global:interface.FindName("textboxPath")
$Global:buttonPath = $Global:interface.FindName("buttonPath")
$Global:buttonFermer = $Global:interface.FindName("buttonFermer")
$Global:buttonReinitialiser = $Global:interface.FindName("buttonReinitialiser")
$Global:listBoxReadOnlyGroups = $Global:interface.FindName("listBoxReadOnlyGroups")
$Global:listBoxModifyGroups = $Global:interface.FindName("listBoxModifyGroups")
$Global:buttonAddGroup = $Global:interface.FindName("buttonAddGroup")

# Fonction pour activer les champs
function Enable-Fields {
 $textboxSearchUser.IsEnabled = $true
 $buttonSearchUser.IsEnabled = $true
 $textboxPath.IsEnabled = $true
 $buttonPath.IsEnabled = $true
 $listBoxReadOnlyGroups.IsEnabled = $true
 $listBoxModifyGroups.IsEnabled = $true
 $buttonReinitialiser.IsEnabled = $true
 $buttonFermer.IsEnabled = $true
}

# Fonction pour désactiver les champs
function Disable-Fields {
 $textboxSearchUser.IsEnabled = $false
 $buttonSearchUser.IsEnabled = $false
 $textboxPath.IsEnabled = $false
 $buttonPath.IsEnabled = $false
 $listBoxReadOnlyGroups.IsEnabled = $false
 $listBoxModifyGroups.IsEnabled = $false
 $buttonReinitialiser.IsEnabled = $false
 $buttonFermer.IsEnabled = $false
}

# Ajouter un événement pour activer les champs lorsque le numéro de ticket est renseigné
$txtWorkorder.Add_TextChanged({
 if ($txtWorkorder.Text -ne "") {
 Enable-Fields
 } else {
 Disable-Fields
 }
})

# Ajouter un événement pour n'accepter que des chiffres dans le champ numéro de ticket
$txtWorkorder.Add_PreviewTextInput({
 if ($_.Text -notmatch '^\d$') {
 $_.Handled = $true
 }
})

# Fonction de recherche dans Active Directory
function Search-ADUser {
 param (
 [string]$searchTerm,
 [string]$ticketNumber
 )
 try {
 # Rechercher l'utilisateur par SamAccountName, DisplayName ou Mail
 $user = Get-ADUser -Filter {
 SamAccountName -eq $searchTerm -or 
 DisplayName -eq $searchTerm -or 
 Mail -eq $searchTerm
 } -Properties SamAccountName, DisplayName, Mail, MemberOf
 if ($user) {
 Write-Host "Utilisateur trouvé : $($user.DisplayName) ($($user.SamAccountName)) - Email : $($user.Mail)"
 [System.Windows.MessageBox]::Show("Utilisateur trouvé : $($user.DisplayName) ($($user.SamAccountName)) - Email : $($user.Mail)")
 # Rechercher les groupes NAS et COM dans les groupes de l'utilisateur
 $nasGroups = @()
 $comGroups = @()
 foreach ($group in ($user 
 Select-Object -ExpandProperty MemberOf)) {
 if ($group -like "*OU=Groupes,DC=fr,DC=domain,DC=ad") {
 try {
 $groupObj = Get-ADGroup -Identity $group -ErrorAction Stop
 $groupName = $groupObj.Name
 if ($groupName -match "^NAS\w{3}\d{2}$") {
 $nasGroups += $groupName
 } elseif ($groupName -match "^COM\w{3}") {
 $comGroups += $groupName
 }
 } catch {
 Log-Error "Erreur lors de la récupération du groupe : $_" $ticketNumber
 }
 }
 }
 Write-Host "Groupes NAS trouvés : $($nasGroups -join ', ')"
 Write-Host "Groupes COM trouvés : $($comGroups -join ', ')"
 $textboxNAS.Text = ($nasGroups -join ", ")
 $textboxCOM.Text = ($comGroups -join ", ")
 } else {
 [System.Windows.MessageBox]::Show("Utilisateur non trouvé.")
 }
 } catch {
 Log-Error "Erreur lors de la recherche : $_" $ticketNumber
 [System.Windows.MessageBox]::Show("Erreur lors de la recherche. Voir le fichier de log pour plus de détails.")
 }
}

# Fonction pour réinitialiser les champs
function Reset-Fields {
 $textboxSearchUser.Clear()
 $textboxNAS.Clear()
 $textboxCOM.Clear()
 $textboxPath.Clear()
 $txtWorkorder.Clear()
 $listBoxReadOnlyGroups.Items.Clear()
 $listBoxModifyGroups.Items.Clear()
}

# Fonction pour obtenir les autorisations NTFS et filtrer les groupes
function Get-NTFSPermissions {
 param (
 [string]$path
 )
 $permissions = Get-Acl -Path $path
 $readOnlyGroups = @()
 $modifyGroups = @()
 foreach ($access in $permissions.Access) {
 $groupName = $access.IdentityReference.Value -replace "^domain\\", ""
 if ($access.FileSystemRights -eq "ReadAndExecute, Synchronize") {
 $readOnlyGroups += $groupName
 } elseif ($access.FileSystemRights -eq "Modify, Synchronize" -or $access.FileSystemRights -eq "ReadAndExecute, Modify, Synchronize") {
 $modifyGroups += $groupName
 }
 }
 return @{ ReadOnlyGroups = $readOnlyGroups; ModifyGroups = $modifyGroups }
}

# Définir la fonction Check-Inheritance
function Check-Inheritance {
 param (
 [string]$path
 )
 $acl = Get-Acl -Path $path
 return $acl.AreAccessRulesProtected -eq $false
}

# Bouton pour parcourir les répertoires
$buttonPath.Add_Click({
 try {
 $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
 $folderBrowser.Description = "Sélectionnez un répertoire"
 $folderBrowser.ShowNewFolderButton = $true
 if ([System.IO.Directory]::Exists($textboxPath.Text)) {
 $folderBrowser.SelectedPath = $textboxPath.Text
 } else {
 $folderBrowser.SelectedPath = [Environment]::GetFolderPath("Desktop")
 }
 if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
 $textboxPath.Text = $folderBrowser.SelectedPath
 $groups = Get-NTFSPermissions -path $folderBrowser.SelectedPath
 $listBoxReadOnlyGroups.Items.Clear()
 $listBoxModifyGroups.Items.Clear()
 foreach ($group in $groups.ReadOnlyGroups) {
 $listBoxReadOnlyGroups.Items.Add($group)
 }
 foreach ($group in $groups.ModifyGroups) {
 $listBoxModifyGroups.Items.Add($group)
 }
 if (-not (Check-Inheritance -path $folderBrowser.SelectedPath)) {
 [System.Windows.MessageBox]::Show("Les héritages sont désactivés pour ce répertoire.")
 }
 }
 } catch {
 Log-Error "Erreur lors de la sélection du répertoire : $_" $txtWorkorder.Text
 [System.Windows.MessageBox]::Show("Erreur lors de la sélection du répertoire. Voir le fichier de log pour plus de détails.")
 }
})

# Bouton pour ajouter un utilisateur au groupe
$buttonAddGroup.Add_Click({
 try {
 $selectedGroup = $listBoxReadOnlyGroups.SelectedItem
 if (-not $selectedGroup) {
 $selectedGroup = $listBoxModifyGroups.SelectedItem
 }
 if ($selectedGroup) {
 $userName = $textboxSearchUser.Text
 if ($userName) {
 $group = Get-ADGroup -Filter { Name -eq $selectedGroup }
 if ($group) {
 $user = Get-ADUser -Identity $userName -Properties MemberOf
 if ($user.MemberOf -contains $group.DistinguishedName) {
 [System.Windows.MessageBox]::Show("L'utilisateur $userName est déjà membre du groupe $selectedGroup")
 } else {
 Add-ADGroupMember -Identity $group -Members $userName
 [System.Windows.MessageBox]::Show("Utilisateur $userName ajouté au groupe $selectedGroup")
 Log-Info "Utilisateur $userName ajouté au groupe $selectedGroup" $txtWorkorder.Text
 }
 } else {
 [System.Windows.MessageBox]::Show("Groupe $selectedGroup non trouvé.")
 }
 } else {
 [System.Windows.MessageBox]::Show("Veuillez rechercher un utilisateur.")
 }
 } else {
 [System.Windows.MessageBox]::Show("Veuillez sélectionner un groupe.")
 }
 } catch {
 Log-Error "Erreur lors de l'ajout de l'utilisateur au groupe : $_" $txtWorkorder.Text
 [System.Windows.MessageBox]::Show("Erreur lors de l'ajout de l'utilisateur au groupe. Voir le fichier de log pour plus de détails.")
 }
})

# Bouton pour réinitialiser les champs
$buttonReinitialiser.Add_Click({
 try {
 Reset-Fields
 } catch {
 Log-Error "Erreur lors de la réinitialisation des champs : $_" $txtWorkorder.Text
 [System.Windows.MessageBox]::Show("Erreur lors de la réinitialisation des champs. Voir le fichier de log pour plus de détails.")
 }
})

# Bouton pour fermer l'application
$buttonFermer.Add_Click({
 try {
 $Global:interface.Close()
 } catch {
 Log-Error "Erreur lors de la fermeture de l'application : $_" $txtWorkorder.Text
 [System.Windows.MessageBox]::Show("Erreur lors de la fermeture de l'application. Voir le fichier de log pour plus de détails.")
 }
})

# Bouton pour rechercher un utilisateur
$buttonSearchUser.Add_Click({
 try {
 $searchTerm = $textboxSearchUser.Text
 if ($searchTerm -ne "") {
 Search-ADUser -searchTerm $searchTerm -ticketNumber $txtWorkorder.Text
 } else {
 [System.Windows.MessageBox]::Show("Veuillez entrer un terme de recherche.")
 }
 } catch {
 Log-Error "Erreur lors de la recherche de l'utilisateur : $_" $txtWorkorder.Text
 [System.Windows.MessageBox]::Show("Erreur lors de la recherche de l'utilisateur. Voir le fichier de log pour plus de détails.")
 }
})

# Ajouter les événements KeyDown pour les zones de texte
$textboxSearchUser.Add_KeyDown({
 if ($_.Key -eq "Enter") {
 $buttonSearchUser.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
 }
})
$textboxPath.Add_KeyDown({
 if ($_.Key -eq "Enter") {
 $buttonPath.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
 }
})

# Afficher la fenêtre
$null = $Global:interface.ShowDialog()