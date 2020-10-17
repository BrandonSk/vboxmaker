#!/bin/bash
#
# Original script created in 2013
# by Branislav Susila.
# Free to download, free to use
# Visit www.vboxgenie.net for updates
# ____________________________________________

function show_summary
{
  # Function used by Creation wizzard - shows info about the machine which is being created
  clear

  echo ____________________________________________
  echo
  echo "    VirtualBox virtual machine creator    "
  echo "       (C) 2014 Branislav Susila"
  echo ____________________________________________
  echo
  echo "Virtual machine name: $VMname"
  echo "Path to files: $VMPath"
  echo "# of CPUs: $CPUcount  CPU execution cap: $CPUexcap%  Virtualization? [$HWvi]"
  echo "RAM: $RAMsize MB   Video RAM: $VGAsize MB  3D-accel: $Accel3d"
  echo "Chipset: $Chipset  Firmware: $Firmware "
  echo "Controllers:"
  for (( j=1; j<=${#CTLs[@]}; j++ ))
    do
      echo -n " #$j ${CTLNames[$j]} (${CTLs[$j]}; ${CTLtype[$j]});"
    done
  echo
  echo "Disks: "
  for (( j=0; j<=("$DISKcount"-1); j++ ))
    do
      echo " #$j ${DISKtype[$j]} (${DISKsize[$j]:7} MB; ${DiskCTL[$j]}; ${DISKmedium[$j]});"
    done
  echo
  tmpcmd="--boot?"
  echo "Boot order (1-4): " ${bootorder//$tmpcmd/}
  echo
  echo "OS type: $OStype"
  if [[ -n OTHoptions ]]; then
    echo "Other options:"
    echo "$OTHoptions"
  fi
  echo "____________________________________________"
}

function panic_on_error
{
  # Error handling function - not actually handling errors, but called from code for unexpected selections
  echo "!!! PANIC !!! PANIC !!! PANIC !!!"
  echo "Error has occured. The script says:"
  echo "$1"
  echo "in the function: $2"
  exit 1
}

# Collect information functions
{
  function get_vm_name
  {
    # Get machine name; VMname and VMpath are global variables
    show_summary
    echo "Enter new virtual machine name "
    echo -n "(Spaces will be replaced with '_'): "
    read VMname
    while [ -z "$VMname" ] ; do
      echo -n "Enter new virtual machine name: "
      read VMname
    done
    VMname=${VMname// /_}
    VMPath="/home/$(id -u -n)/VirtualBox VMs/$VMname"
  }

  # Other settings
    function sub_get_other_settings()
    {
      # Function called by "get_other_settings" and receives as argument a single line from input file (see get_other_settings)
      local arrIN
      oIFS=$IFS
      IFS=';' read -a arrIN <<< "$1"
      IFS=$oIFS
      echo
      echo "<<< ${arrIN[0]} >>>"
      show_menu YESNO[@] "${arrIN[2]}:" "> " "no" "no"
	  if [[ "$MenuSel" = "yes" ]]; then
	    OTHoptions="$OTHoptions ${arrIN[1]} on "
	    echo "$OTHoptions"
	  fi
    }
    
    function get_other_settings
    {
    # Function processes the "vbox_onoff_options" input file; OTHoptions  is global variable
    if [ -z "$1" ]; then show_summary; fi
      local filecontent
      echo; echo "Now we will configure bunch of on/off settings: "; echo
      OTHoptions=""
      if [[ -e vbox_onoff_options ]]; then
	oIFS=$IFS
	IFS=$'\r\n' filecontent=($(cat vbox_onoff_options))
	IFS=$oIFS
	for line in "${filecontent[@]}"
	  do
	    sub_get_other_settings "$line"
	  done
      else
	echo "Input file 'vbox_onoff_options' not found!"
	echo "Skipping this configuration part. (Wait 3 seconds)"
	sleep 3
      fi
    }
    
    function define_ostype
      {
	# Function requests user to choose which OS will be installed in the VM
	show_summary
	initialize_ostypes
	show_menu OSTYPES[@] "Please select the operating system you intend to use:" "Choose operating system: " "no" "no"
	OStype="$MenuSel"
	unset OSTYPES
      }

  # DISK related functions
  {
    function get_hdd_details
    {
	# Function collects details about each individual disk -> type HDD; either virtual or raw access
	# All important information is stored in arrays beginning with DISK; other variables are local
	# $1 argument (compulsory) is the index of the array element
	local repeat=1 rpt2=1 AccessType VDIname VDIsize fullpath
	local atmpMNU=('virtual disk file' 'RAW access to partition')
	
	if [ -z "$1" ]; then panic_on_error "Argument 1 not optional." "get_hdd_details"; else local i=$1; fi
	
	while [ $repeat -ne 0 ] ; do
	  show_menu atmpMNU[@] "no" "Choose type of disk: " "no" "no"
	  AccessType="$REPLY"
	  case "$AccessType" in
	      '1') echo
		    VDIsize=0		# also determines, whether it is existing VDI (0) or new (>0)
		    while [ $rpt2 -ne 0 ] ; do
		      VDIname=""
		      while [ "$VDIname" = "" ];
		      do
			echo -n "Enter the name of the virtual disk file (without vdi extenstion): "
			read VDIname
		      done
		      VDIname="$VDIname.vdi"
		      fullpath="$VMPath/$VDIname"
		      if [ -e "$fullpath" ] ; then
			echo "File found: $fullpath"; echo "It will be attached to the VM."; sleep 1
		      else
			echo -n 
			show_menu YESNO[@] "no" "File does not exist. Create a new VDI file?: " "no" "no"
			if [ "$MenuSel" != "yes" ] ; then
			  rpt2=1
			else
			  while [ $VDIsize -le 0 ] ; do
			    echo -n "Size of the new VDI file (in MB): "
			    read VDIsize
			    case $VDIsize in
				''|*[!0-9]*) VDIsize=0 ;;
				*) echo OK ;;
			    esac
			  done
			  rpt2=0
			fi
		      fi
		      
		    done
		    DISKsize[i]="--size $VDIsize"
		    DISKmedium[i]="\"$fullpath\""
		    repeat=0
		    ;;
	      '2') echo
		    echo "This option is for experts only! Are you sure?"
		    echo "Pre-requisites:"
		    echo "    1) You must have write rights to disk devices (e.g. mamber of the 'disk' group on Ubuntu)"
		    echo "    2) know to which disks and partitions to enable RAW access."
		    echo
		    show_menu YESNO[@] "no" "Do you want to continue? " "no" "no"
		    if [ "$MenuSel" != "yes" ] ; then
		      repeat=1
		    else
		      echo "OK" # Here goes the whole RAW access stuff
		      VDIname=""
		      while [ "$VDIname" = "" ]
		      do
			echo -n "Enter name for the RAW disk access definition file (without extension): "
			read VDIname
			if [ -e "$VMPath/$VDIname.vdmk" ]; then echo "File already exist. Choose another name." && VDIname=""; fi
		      done
		      fullpath="$VMPath/$VDIname.vdmk"
		      echo
		      DISKdevice=""
		      while [ "$DISKdevice" = "" ]
		      do
			echo -n "Enter physical disk device (e.g. /dev/sdb): "
			read DISKdevice
			if [ !-e "$DISKdevice" ]; then echo "Device not found! Please correct it." && DISKdevice=""; fi
		      done
		      echo
		      echo "Enter partition numbers, which you want to become accessible (e.g. 1,2,5): "
		      read DISKpartition
			# ADD CHECK FOR CORRECT PATTERN and that each partition exists... (maybe sometime > this is for experts :) )
		      DISKsize[i]="-rawdisk $DISKdevice -partitions $DISKpartition"
		      DISKmedium[i]="\"$fullpath\""
		      DISKtype[i]="r"	# This is to distinguish between raw and virtual disks
		      repeat=0
		    fi
		    ;;
	      *) repeat=1 ;;
	  esac
	done
    }
    function get_dvd_details
    {
	# Collects information regarding the DVD device (in other words, path to ISO file)
	local repeat=1 Medium
	if [ -z "$1" ]; then panic_on_error "Argument 1 not optional." "get_dvd_details"; else local i=$1; fi
	
	while [ $repeat -ne 0 ] ; do
	  echo "Enter path to ISO file to attach or type leave blank for empty drive:"
	  read Medium
	  if [ -z "$Medium" ] ; then
	    DISKmedium[i]="\"emptydrive\""
	    repeat=0
	  else
	    if [ -e $Medium ] ; then
	      DISKmedium[i]="\"$Medium\""
	      repeat=0
	    else
	      echo "Oooops. The file you specified does not exist. Please try again (full path)."
	      repeat=1
	    fi
	  fi
	done
	DISKsize[i]=0	# dummy, just to keep array indexes aligned 1:1 (probably useless anyway, as array does not have to be continous
    }
    function get_fdd_details
    {
	echo "FDD not yet supported, sorry"
	sleep 2
    }
    function specify_disk_type
    {
	# Function called for each disk -> first asks for what type of disk it is, then calls another function to collect details
	# Argument 1 (compulsory) is the index of the array element
	local DISKTYPES=('HDD (virtual or Raw access)' 'DVD (path to ISO)' 'FDD (not supported yet)')
	local tmpR=0 maxport
	if [ -z "$1" ]; then panic_on_error "Argument 1 not optional." "get_hdd_details"; else local i=$1; fi
	
	show_menu DISKTYPES[@] "Please specify disk type: " "Disk type: " "no" "no"
	    case $REPLY in
	      1) DISKtype[i]="h" ;;
	      2) DISKtype[i]="d" ;;
	      3) DISKtype[i]="f" ;;
	      *) panic_on_error "Oooops ooops, you should never get here! (MenuSel=$MenuSel)" "function specify_disk_type; 1st case statement";;
	    esac
	# Later in HDD details definition we will replace the 'h' with 'r' for RAW access disks
	case ${DISKtype[i]} in
	    'h') get_hdd_details $i ;;
	    'd') get_dvd_details $i ;;
	    'f') get_fdd_details $i ;;
	    *) panic_on_error "Oooops ooops, you should never get here! (MenuSel=$MenuSel)" "function specify_disk_type; 2nd case statement";;
	esac
	show_menu CTLNames[@] "Attach to which controller?" "Select controller: " "no" "no"
	DiskCTL[i]="$MenuSel"
	case "${CTLs[$REPLY]}" in
	  'IDE') maxport=4 ;;
	  'SATA') maxport=30 ;;
	  'SCSI') maxport=15 ;;
	  'SAS') maxport=8 ;;
	  *) panic_on_error "Oooops ooops, you should never get here. (case CTLtype=${CTLs[$REPLY]})" "specify_disk_type";;
	esac
	
	# We will also store the type of controller into DiskCTL field for extraction later, when adding disk...
	# It is necessary, because for ide we must modify the port and device numbers.
	DiskCTL[i]="${DiskCTL[$i]};${CTLs[$REPLY]}"
	while [ $tmpR -le 0 ] ; 
	do
	  echo -n "Attach to port #: "
	  read tmpR
	  case $tmpR in
	      ''|*[!0-9]*) tmpR=0 ;;
	      *) if [ $tmpR -gt $maxport ]; then
		    echo "Maximum number of poerts for $MenuSel controller is $maxport !"
		    tmpR=0
		  fi
		;;
	  esac
	done
	DiskPort[i]=$tmpR
    }
    function collect_disks_information
    {
      local tmpR="yes"
      DISKcount=0
      show_summary
      echo; echo " > Now you can add disks to your VM. You must add at least one. <"; echo
      while [[ "$tmpR" = "yes" ]]
      do
	(( DISKcount++ ))
	echo "Collecting information for disk #$DISKcount:"
	specify_disk_type $DISKcount
	echo "Disk added successfully."
	show_menu YESNO[@] "Would you like to add another disk?" "Add another? " "no" "no"
	tmpR="$MenuSel"
      done
    }

  }
  
  # NIC related functions
  {
    function specify_nic_type
    {
      # Function specifies NIC type, operating mode and relevant details for the current NIC
      # Argument 1 (compulsory) is the index of the array element
      local NICS=('Am79C970A' 'Am79C973' '82540EM' '82543GC' '82545EM' 'virtio')
      local tmpS1 tmpS2 tmpS3
      if [ -z "$1" ]; then panic_on_error "Argument 1 not optional." "specify_nic_type"; else local i=$1; fi

      
      echo "First 2 should work in all systems, 3-5 are Intel emulation, 6 is not supported by this script"
      show_menu NICS[@] "Specify network card type:" "> " "no" "no"
      NICtype[i]="$MenuSel"

      NICS=('none' 'null' 'nat' 'bridged' 'intnet' 'hostonly' 'generic')
      show_menu NICS[@] "Specify mode in which NIC$i (type ${NICtype[i]}) will operate:" "> " "no" "no"
	NICmode[i]="$MenuSel"
      
      case "${NICmode[i]}" in
	'none') NICother[i]="" ;;
	'null') NICother[i]="" ;;
	'nat') echo
	    echo -n "Enter name of NAT network: "
	    read tmpS1
	    echo -n "Enter the network interface in format (a.b.c.0; e.g. 192.168.123.0): "
	    read tmpS2
	    echo "Choose network mask (sorry, subnets not available at the moment: "
	    tmpS3=('255.0.0.0' '255.255.0.0' '255.255.255.0')
	    show_menu tmpS3[@] "no" "Network mask option: " "no" "no"
		tmpS3=$[$REPLY*8]
	    echo
	    show_menu YESNO[@] "no" "Enable DHCP on the Nat network?" "no" "no"
	    tmpcmd=""
		if [[ $REPLY -eq 1 ]]; then tmpcmd="-h on"; fi
	    NICother[i]="-t $tmpS1 -n \"$tmpS2/$tmpS3\" -e $tmpcmd"
	    ;;
	'bridged') echo "Select to which HW NIC the bridged adapter will connect to: "
	    readarray tmpS1 < <(ifconfig | grep 'eth' | awk '{print $1}')
	    readarray tmpS2 < <(ifconfig | grep 'wlan' | awk '{print $1}')
	    tmpS3=( "${tmpS1[@]/$'\x0a'/ }" "${tmpS2[@]/$'\x0a'/ }" )
	    show_menu tmpS3[@] "no" "Choose an adapter: " "no" "no"
	      NICother[i]="--bridgeadapter$i"
	      NICother[i]="${NICother[i]} $MenuSel"
	    ;;
	'intnet') echo
	    echo -n "Enter name of internal network: "
	    read tmpS1
	    NICother[i]="--intnet$i $tmpS1" ;;
	'hostonly') echo "Select to which host's HW NIC will be used for host-only network: "
	    readarray tmpS1 < <(ifconfig | grep 'eth' | awk '{print $1}')
	    readarray tmpS2 < <(ifconfig | grep 'wlan' | awk '{print $1}')
	    tmpS3=( "${tmpS1[@]/$'\x0a'/ }" "${tmpS2[@]/$'\x0a'/ }" )
	    show_menu tmpS3[@] "no" "Choose an adapter: " "no" "no"
	      NICother[i]="--hostonlyadapter$i $MenuSel"
	    ;;
	'generic') NICother[i]=""
	  echo
	  echo "*************   OK, BUT...   ********************"
	  echo "[generic] has LIMITED support at this moment!"
	  echo "Manual configuration of properties must be done!"
	  echo "*************************************************"
	  echo "Continuing in 3 seconds"
	  sleep 3
	  ;;
	*) panic_on_error "Oooops ooops, you should never get here! (MenuSel=$MenuSel; REPLY=$REPLY)" "function specify_nic_type";;
      esac    
    }

    function collect_nics_information
    {
      local tmpR
      NICcount=0
      show_summary
      echo; echo " > Now you can add Network Interface Cards to your VM. <"; echo
      show_menu YESNO[@] "Would you like to add a NIC?" "Add new NIC? " "no" "no"
      tmpR="$MenuSel"
      while [[ "$tmpR" = "yes" ]]
      do
	(( NICcount++ ))
	echo "Collecting information for NIC #$NICcount:"
	specify_nic_type $NICcount
	echo "NIC #$NICcount added successfully."
	show_menu YESNO[@] "Would you like to add another NIC?" "Add another? " "no" "no"
	tmpR="$MenuSel"
	if [[ $NICcount -eq 32 ]]; then echo "Maximum number of NICs (32) reached. Cannot add another."; sleep 2; tmpR="no"; fi
      done
    }
    }
  
  # CPU, RAM & MB
  {
    function define_cpu_parameters
    {
      # When you pass parameter to this function, it means you are modifying an existing machine,
      # therefore summary will not be shown.
      
      #Get CPU count
      if [ -z "$1" ]; then show_summary; fi
      CPUcount=0
      re='^[0-9]+$'

      while [ $CPUcount -le 0 ] ; do
	echo -n "Number of CPUs: "
	read CPUcount
	case $CPUcount in
	    ''|*[!0-9]*) CPUcount=0 ;;
	    *) echo OK ;;
	esac
      done
      
      # Execution cap
      if [ -z "$1" ]; then show_summary; fi
      echo
      CPUexcap=101
      while [[ CPUexcap -ge 101 ]]; do
	echo -n "CPU execution cap (1-100)?: "
	read CPUexcap
	if [[ CPUexcap -le 0 || CPUexcap -ge 101 ]]; then
	  CPUexcap=101
	fi
      done
      
      # HW virtualization?
      if [ -z "$1" ]; then show_summary; fi
      show_menu YESNO[@] "Enable HW virtualization?" "> " "no" "no"
      HWvi="$MenuSel"
    }

    function define_mb_parameters
    {
      # When parameter is passed to the function, it means you are modifying, so summary is not shown.
      local CHIPSETS=('ich9' 'piix3') FIRMWARES=('bios' 'efi' 'efi32' 'efi64')

      # Chipset
      if [ -z "$1" ]; then show_summary; fi
      show_menu CHIPSETS[@] "Please select the chipset you want to emulate: " "> " "no" "no"
      Chipset="$MenuSel"
	
      # Firmware
      if [ -z "$1" ]; then show_summary; fi
      show_menu FIRMWARES[@] "Please select the firmware you want to emulate: " "> " "no" "no"
      Firmware="$MenuSel"
      }
    
    function get_ram_size
    {
      # Passed parameter = you are modifying, so no summary
      # Get RAM size
      if [ -z "$1" ]; then show_summary; fi
      RAMsize=0
      while [ $RAMsize -le 0 ] ; do
	echo -n "Amount of RAM (MB): "
	read RAMsize
	case $RAMsize in
	    ''|*[!0-9]*) RAMsize=0 ;;
	    *) echo OK ;;
	esac
      done
    }
    
    function get_controller_details
    {
      # $1 is the index for array
      # $2 is the name of the controller, but is used only when modifying an existing one
      local ctlidx=$1 tstr="$2"
      local CTLTYPES=('IDE' 'SATA' 'SCSI' 'SAS')
	show_menu CTLTYPES[@] "Select #$ctlidx controller type: " "Your choice: " "no" "no"
	CTLs[ctlidx]="$MenuSel"
	if [ -z "$2" ]; then
	  echo -n "Input name [<Empty> for default CTL_$MenuSel]: "
	  read tstr
	  if [[ -z "$tstr" ]]; then tstr="CTL_$MenuSel"; fi
	fi
	CTLNames[ctlidx]="$tstr"
	case "$MenuSel" in
	  'IDE') local SATATYPES=('PIIX3' 'PIIX4' 'ICH6')
	    ;;
	  'SATA') local SATATYPES=('IntelAHCI')
	    ;;
	  'SCSI') local SATATYPES=('LSILogic' 'BusLogic')
	    ;;
	  'SAS') local SATATYPES=('LSILogicSAS')
	    ;;
	  *) panic_on_error "You should never get here! (case)" "get_controller_details"
	    ;;
	  # Note, the I82078 controller is for floppies, which are not supported for now.
	esac
	
	show_menu SATATYPES[@] "Pick the controler type: " "Choose controller type: " "no" "no"
	CTLtype[ctlidx]="$MenuSel"
    }
    
    function get_controllers
    {      
      # Try not to modify ControllerIndex variable elsewhere, as we will rely on it in as a counter
      ControllerIndex=0
      MenuSel=""
      echo "Now adding disk controllers to the system. You must add at least 1."
      while [ "$MenuSel" != "no" ] ;
      do
	ControllerIndex=$((ControllerIndex+1))
	get_controller_details $ControllerIndex
	echo "Controler #$ControllerIndex added successfully."
	show_menu YESNO[@] "Do you want to add another controller?" "?> " "no" "no"
      done
    }

  # Video
    function define_vga_parameters
    {
      # Passed parameter = you are modifying so no summary
      # VGA size
      if [ -z "$1" ]; then show_summary; fi
      VGAsize=0
      while [ $VGAsize -le 0 ] ; do
	echo -n "Amount of Video memory (MB): "
	read VGAsize
	case $VGAsize in
	    ''|*[!0-9]*) VGAsize=0 ;;
	    *) echo OK ;;
	esac
      done
      # 3D accelleration
      echo
      show_menu YESNO[@] "Do you want to enable 3D accelleration?" "> " "no" "no"
	  if [[ $REPLY -eq 1 ]]; then
	    Accel3d="--accelerate3d on"
	  else
	    Accel3d=""
	  fi
    }

  function define_boot_order()
  {
    local BOOTDEVICES=('none' 'floppy' 'dvd' 'disk' 'net')
    bootorder=""
    for (( i=1; i<=4; i++ ))
      do
	# Passed parameter = you are modifying, so no summary
	if [ -z "$1" ]; then show_summary; fi
	echo
	show_menu BOOTDEVICES[@] "Please select boot device #$i:" "> " "no" "no"
	bootorder="$bootorder --boot$i $MenuSel"
      done
  }
  }

}

function create_wizzard
{
  # <><><><><><><><><><><><><><><><><><><>
  # PART 1 - Collect information about VM
  # <><><><><><><><><><><><><><><><><><><>

  # VM name
    get_vm_name
  # CPU
    define_cpu_parameters
  # RAM size
    get_ram_size
  # Video settings
    define_vga_parameters
  # Motherboard
    define_mb_parameters
    show_summary
  # Controllers
    get_controllers
  # Disks
    collect_disks_information
  # Boot order
    define_boot_order
  # Network Interface Cards
    collect_nics_information
  # Operating system selection
    define_ostype
  # Other settings (e.g. Remote Desktop)
    get_other_settings
    
    wizzard_finished=1

  show_summary
}

# Create VM functions
{
function run_command
{
  # Argument #3 means we are modifying a machine and thus override/reset the DumpComm variable
  # Later we can modify this behaviour and pass #3 only if we want to dump... but now it is too late :)
  local tstr="$1"
  if [[ -n "$3" ]]; then DumpComm=""; fi
  if [[ -n $2 ]]; then
    echo "Executing: $2"
  fi
  
  if [[ -n "$DumpComm" ]]; then
    echo "# $2" >> "$DumpComm"
    echo "${tstr//$VMname/'$VMname'}" >> "$DumpComm"
  fi
  
  eval $1
  local ES=$?
  
  if [[ $ES != 0 ]]; then
    echo "ERROR while creating the Virtual Machine $VMname !"
    echo "Panic! Exiting..."
    echo
    echo "Details: "
    echo "Failed command: \"$1\" "
    echo "Exit status: $ES"
    exit 2
  fi
}

function add_disk()
{
  # $1 - index; $2 - disk type; $3 - disk size; $4 - disk medium
  #echo "Disk #$1: type[$2], size[$3], medium[$4]"
  
  # extract data from DiskCTL and adjust port string for IDE if necessary
  # tmpS2 will hold the CTLtype and tmpS3 the CTLName
  local tmpS1="${DiskCTL[$1]}" tmpS2 tmpS3 tmpcmd="" desc="" tmpR=${DiskPort[$1]}
  tmpS2="${tmpS1##*;}"
  tmpS3="${tmpS1%%;*}" 
  if [ "$tmpS2" == "IDE" ]; then
    case $tmpR in
      1) tmpS1="--port 0 --device 0" ;;
      2) tmpS1="--port 0 --device 1" ;;
      3) tmpS1="--port 1 --device 0" ;;
      4) tmpS1="--port 1 --device 1" ;;
      *) panic_on_error "You should never get here. (case tmpR=$tmpR)" "add_disk" ;;
    esac
  else
    tmpS1="--port $tmpR --device 0"
  fi
  
  case "$2" in
    f) echo "Sorry, FDD not yet supported" ;;
    d) desc="Attaching DVD drive to VM"
	tmpcmd="VBoxManage storageattach $VMname --storagectl $tmpS3"
	tmpcmd="$tmpcmd $tmpS1 --type dvddrive --medium $4"
	run_command "$tmpcmd" "$desc"
      ;;
    [hr]) if [[ "$2" == "h" ]]; then
		  desc="Creating VDI file"
		  tstr="createhd --filename"
	      else
		  desc="Creating VDMK file for RAW access"
		  tstr="internalcommands createrawvmdk -filename"
	      fi
	tmpcmd="VBoxManage $tstr $4 $3"
	run_command "$tmpcmd" "$desc"
	desc="Attaching disk to VM"
	tmpcmd="VBoxManage storageattach $VMname --storagectl $tmpS3"
	tmpcmd="$tmpcmd $tmpS1 --type hdd --medium $4"
	run_command "$tmpcmd" "$desc"
      ;;
    *) panic_on_error "Panic! You should never get here!" "Details: add_disk $1, $2, $3, $4"
      exit 2
      ;;
  esac
}

function add_disks()
{
  for (( i=1; i<=($DISKcount); i++ ))
  do
    add_disk $i ${DISKtype[i]} "${DISKsize[i]}" "${DISKmedium[i]}"
  done
}

function add_nic()
{
  local tmpcmd="VBoxManage modifyvm $VMname --nic$1 $3 --nictype$1 $2 $4"
  local desc="Adding NIC #$1 to the VM"
  run_command "$tmpcmd" "$desc"
}

function add_nics()
{
  for (( i=1; i<=("$NICcount"); i++ ))
  do
    add_nic $i ${NICtype[i]} ${NICmode[i]} "${NICother[i]}"
  done
}

function make_dump_script()
{
  # Defines, whether creation commands are also dumped to a shell script file. DumpComm (global) contains the full path to the file.
  local export_dir="exported_scripts"
  echo "Do you want to dump the creation commands into a file?"
  echo "(Hint: You may later just make the file a shell script and re-run to recreate the VM.)"
  show_menu YESNO[@] "no" "Create dump script?: " "no" "no"
  if [[ $REPLY -eq 1 ]]; then
    if [ ! -d "$CWD/$export_dir" ]; then mkdir "$CWD/$export_dir"; fi
    DumpComm="$CWD/$export_dir/$VMname-vbox-create.sh"
    if [[ -e "$DumpComm" ]]; then
      echo
      show_menu YESNO[@] "File $DumpComm already exists." "Overwrite?" "no" "no"
      if [[ $REPLY -eq 2 ]]; then
	echo "Dumping into a new script file amended by date and time:"
	DumpComm="${DumpComm%*.sh}-$(date +"%y-%m-%d-%H-%M-%S").sh"
      fi
    fi
    echo "#!/bin/bash" > "$DumpComm"
    echo "# Created by VBOXGENIE script" >> "$DumpComm"
    echo "# (C) 2014 Branislav Susila; www.vboxgenie.net" >> "$DumpComm"
    echo "#" >> "$DumpComm"
    echo 'if [ -z "$1" ]' >> "$DumpComm"
    echo '	then' >> "$DumpComm"
    echo '		echo "You must provide a machine name as input parameter! Do NOT use spaces!"' >> "$DumpComm"
    echo '		echo "Usage: vbmk.sh VMachine_name"' >> "$DumpComm"
    echo '		exit 1' >> "$DumpComm"
    echo '	else' >> "$DumpComm"
    echo '		VMname="$1"' >> "$DumpComm"
    echo 'fi' >> "$DumpComm"
    echo " " >> "$DumpComm"
  else
    DumpComm=""
  fi
}

#Modification functions
{
# Register VM
function register_VM
{
  # Pass VMname as argument
  if [ -n "$1" ]; then VMname="$1"; fi
  local desc="Registering VM"
  local tmpcmd="VBoxManage createvm --name $VMname --register"
  run_command "$tmpcmd" "$desc"
}
  
# CPU
function Modify_CPU
{
  # Pass VMname or UUID as argument
  # Note (applies to all modify functions) I am not passing other arguments, because
  # the variables are either already set via wizzard or the function is called from modify menu and the variables have also then been set.
  if [ -n "$1" ]; then VMname="$1"; fi
  local desc="Defining CPU"
  local tmpcmd="VBoxManage modifyvm $VMname --cpus $CPUcount --cpuexecutioncap $CPUexcap"
  if [[ $HWvi != "no" ]]; then
    tmpcmd="$tmpcmd --hwvirtex on"
  else
    tmpcmd="$tmpcmd --hwvirtex off"
  fi
  run_command "$tmpcmd" "$desc"
}
  
# Motherboard
function Modify_motherboard
{
  # Pass VMname or UUID as argument
  if [ -n "$1" ]; then VMname="$1"; fi
  local desc="Configuring motherboard"
  local tmpcmd="VBoxManage modifyvm $VMname --chipset $Chipset --firmware $Firmware"
  run_command "$tmpcmd" "$desc"
}
  
# Memory
function Modify_RAM
{
  # Pass VMname or UUID as argument
  if [ -n "$1" ]; then VMname="$1"; fi
  local desc="Configuring memory"
  local tmpcmd="VBoxManage modifyvm $VMname --memory $RAMsize"
  run_command "$tmpcmd" "$desc"
}

# Video
function Modify_Video
{
  # Pass VMname or UUID as argument
  if [ -n "$1" ]; then VMname="$1"; fi
  local desc="Configuring video settings"
  local tmpcmd="VBoxManage modifyvm $VMname --vram $VGAsize"
  if [[ -n $Accel3d ]]; then
    tmpcmd="$tmpcmd $Accel3d"
  fi
  run_command "$tmpcmd" "$desc"
}
# HDD, DVD, FDD
function Add_controllers
{
  local i
  for (( i=1; i<=("$ControllerIndex"); i++ ))
    do
      Modify_controller $i
    done
}

function Modify_controller
{
  # First (compulsory) argument is index
  # Second (optional) Pass VMname or UUID as argument 
  if [ -z "$1" ]; then panic_on_error "Not enough arguments provided!" "Modify_controller"; fi
  if [ -n "$2" ]; then VMname="$2"; fi
  local desc="Adding controller #$1"
  local tmpcmd="VBoxManage storagectl $VMname --name ${CTLNames[$1]} --add ${CTLs[$1]} --controller ${CTLtype[$1]}"
  run_command "$tmpcmd" "$desc"
}

# Add other options
function Modify_other_settings
{
  # Pass VMname or UUID as argument
  if [ -n "$1" ]; then VMname="$1"; fi
  local desc="Configuring on/off options"
  local tmpcmd="VBoxManage modifyvm $VMname $OTHoptions"
  run_command "$tmpcmd" "$desc"
}

# Boot order
function Modify_boot_order
{
  # Pass VMname or UUID as argument
  if [ -n "$1" ]; then VMname="$1"; fi
  local desc="Setting boot order"
  local tmpcmd="VBoxManage modifyvm $VMname $bootorder"
  run_command "$tmpcmd" "$desc" 
}

# OS type
function Modify_OS_type
{
  # Pass VMname or UUID as argument
  if [ -n "$1" ]; then VMname="$1"; fi
  local desc="Configuring OS type"
  local tmpcmd="VBoxManage modifyvm $VMname --ostype $OStype"
  run_command "$tmpcmd" "$desc" 
}
}

function create_vm
{
# <><><><><><><><><><><><><><><><><><><>
# PART 2 - Create VM
# <><><><><><><><><><><><><><><><><><><>

  clear
# Dump commands into a log file?
  make_dump_script
  clear
  register_VM
  Modify_CPU
  Modify_RAM
  Modify_other_settings
  Modify_motherboard
  Modify_Video
  Add_controllers
  add_disks
  add_nics
  Modify_boot_order
  Modify_OS_type
# Make dump script executable
  if [[ -n "$DumpComm" ]]; then chmod +x "$DumpComm"; fi
}

}

function show_menu
{
  # Takes parameters:
  #	$1 Array of menu items (when calling pass it as this: show_menu array_of_items[@]
  #	$2 text/no for Menu title or "no" for no menu title; if first char is * then menu title is expanded (* above/below/etc...) 
  #	$3 text for PS3 prompt
  #	$4 text/no - whether to include "text" (e.g. back, quit, etc.) or no
  #	$5 yes/no - whether to clear screen yes or no
  #	$6 if present - adds additional text below the $2
  #
  #	Answer is returned in MenuSel variable and built-in REPLY variable
  
  declare -a MenuItems=("${!1}")
  local sL sS
  if [[ "$5" = "yes" ]]; then
    clear
  fi
  
  if [[ $2 != "no" ]]; then
    if [[ "$2" == \** ]]; then
      # Following prints fancy *** border around the menu title
      local sL=${#2}
      sL=$(($sL + 7))
      printf -v 'sS' '%*s' "$sL"
      echo "${sS// /*}"
      echo "**  ${2:1}  **"
      echo "${sS// /*}"
      echo
    else
      echo "$2"
    fi
  fi
  if [ -n "$6" ]; then echo "$6"; fi

  PS3="$3"
  local -i tmpAL=${#MenuItems[@]}

  if [[ $4 != "no" ]]; then
    let "tmpAL++"
    MenuItems=( "${MenuItems[@]}" "$4" )
  fi

  select MenuSel in "${MenuItems[@]}";
  do
    case 1 in
      $(($REPLY<=0))) echo "Choose from interval 1 to $tmpAL"
		      ;;
      $(($REPLY<=$tmpAL))) break
			  ;;
      *) echo "Wrong selection"
	  ;;
    esac
  done
  unset MenuItems
  PS3=""
  # After function exists, Reply holds the numerical value of selection and MenuSel the string.
  # Assign these to other variables in the calling routine, as they get overwritten when this function is called again
}

function initialize_constants
{
  ## Variables and Constants
  YESNO=('yes' 'no')
  UName="$USER"
  VMPath=""
  CWD=$(pwd)
  aMainMenu=('Define VM wizzard' 'Create VM (run wizzard first!)' 'Modify/Erase existing VMs' 'Control (start/stop/pause) VMs')
}

function initialize_ostypes
{
  local fs tmpS1 tmpS2 tmpA
  readarray fs < <(VBoxManage list ostypes | grep 'ID:')
    i=0
    for tmpS1 in "${fs[@]}";
      do
	echo "S: $tmpS1"
	if [[ "$tmpS1" != Family* ]]; then
	  tmpS2="${tmpS1##* }"
	  tmpA[i]=${tmpS2//[[:blank:]]/}
	  i=$((i+1))
	fi
      done
    OSTYPES=( "${tmpA[@]/$'\x0a'/} " )
}

function initialize_existing_VMs
{
  # Keep the tmpA and VMSs as global! They are used in the calling function.
  unset VMSs
  local fs
  if [ -z "$1" ]; then
    readarray fs < <(VBoxManage list vms)
  else
    readarray fs < <(VBoxManage list runningvms)
  fi
    i=0
    for tmpS1 in "${fs[@]}";
      do
	# First we get everything that is between curly braces -> the UUID; ...and remove the new lice character
	  UUID="${tmpS1##* }"
	  UUID="${UUID/$'\x0a'/}"
	# Now in the array we store MachineName|UUID  
	  tmpA[i]="${tmpS1%{*}|$UUID"
	  VMSs[i]="${tmpS1%{*}"
	  i=$((i+1))
      done
    unset fs
}

function modify_existing_VM
{
  initialize_existing_VMs
  # show sub menu
  local tmpR=0
  while [[ $tmpR != -99 ]];
  do
    show_menu VMSs[@] "*List of existing Virtual Machines" "Select VM you would like to modify: " "Back" "yes"
    if [[ $REPLY = $((${#VMSs[@]}+1)) ]]; then
	  echo "nothing done"
	  tmpR=-99
	else
	  # reference variables
	  curVM="$MenuSel"
	  curUUID="${tmpA[$(($REPLY-1))]##*|}"	  
	  show_modify_submenu "$curVM" "$curUUID"
	  tmpR=0
    fi
  done
  unset VMSs
  unset tmpA
}

function show_modify_submenu
{
  local tmpR=0
  while [[ $tmpR != -99 ]];
  do
    echo "Please wait. Reading VM data..."
    show_VM_properties "$1" "$2"
    local ModifyMenu=('Modify RAM' 'Modify CPU parameters' 'Modify Video settings' 'Modify motherboard settings' 'Modify boot order' 'Modify controller' 'Modify other settings' 'Change OS type' 'Delete the VM')
    show_menu ModifyMenu[@] "Modification options:" "Choose your action: " "Back" "no"
    if [[ $REPLY = $((${#ModifyMenu[@]}+1)) ]]; then
	  echo "nothing done"
	  tmpR=-99
	else
	  
	  case $REPLY in
	    1)	get_ram_size "modifying"
		Modify_RAM "$2"
	      ;;
	    2)	define_cpu_parameters "modifying"
		Modify_CPU "$2"
	      ;;
	    3)	define_vga_parameters "modifying"
		Modify_Video "$2"
	      ;;
	    4)	define_mb_parameters "modifying"
		Modify_motherboard "$2"
	      ;;
	    5)	define_boot_order "modifying"
		Modify_boot_order "$2"
	      ;;
	    6)	local -a CURCONTROLLERS
		readarray CURCONTROLLERS < <(eval "VBoxManage showvminfo "$2" --machinereadable | grep -i "storagecontrollername"")
		CURCONTROLLERS=( "${CURCONTROLLERS[@]/$'\x0a'/}" )
		CURCONTROLLERS=( "${CURCONTROLLERS[@]//\"/}" )
		CURCONTROLLERS=( "Add new" "${CURCONTROLLERS[@]##*=}" )
		show_menu CURCONTROLLERS[@] "Choose controller to modify:" "?> " "no" "no"
		CTLName="$MenuSel"
		case $REPLY in
		  1)
		    get_controller_details 1
		    Modify_controller 1 "$2" "no_dumping"
		    ;;
		  *)
		    local -a CTLACTIONS=('Change type or chip (will remove existing one)' 'Change host IO cache setting' 'Change bootable flag' 'Delete')
		    show_menu CTLACTIONS[@] "What action do you want to perform on controller $CTLName ?" "?> " "no" "no"
		    case "$MenuSel" in
		      'Change type or chip (will remove existing one)')
			# For get_controller_details function we will now use a fixed index of 1
			get_controller_details 1 "$CTLName"
			( VBoxManage storagectl $2 --name $CTLName --remove )
			Modify_controller 1 "$2" "no_dumping!"
			;;
		      'Change host IO cache setting')
			show_menu YESNO[@] "Enable host IO cache?" "?> " "no" "no"
			if [[ $REPLY -eq 1 ]]; then
			  ( VBoxManage storagectl $2 --name $CTLName --hostiocache on )
			else
			  ( VBoxManage storagectl $2 --name $CTLName --hostiocache off )
			fi
			;;
		      'Change bootable flag')
			show_menu YESNO[@] "Make controller bootable?" "?> " "no" "no"
			if [[ $REPLY -eq 1 ]]; then
			  ( VBoxManage storagectl $2 --name $CTLName --bootable on )
			else
			  ( VBoxManage storagectl $2 --name $CTLName --bootable off )
			fi
			;;
		      'Delete')
			( VBoxManage storagectl $2 --name $CTLName --remove )
			;;
		      *)
			panic_on_error "Oooops ooops! You should never get here (third case; MenuSel=$MenuSel)" "show_modify_submenu; controller"
			;;
		    esac
		    ;;
		esac
	      ;;
	    7)	get_other_settings "modifying"
		Modify_other_settings "$2"
	      ;;
	    8)	define_ostype "modifying"
		Modify_OS_type "$2"
	      ;;
	    9)	delete_VM "$1" "$2"
		initialize_existing_VMs
		tmpR=-99
		break
	      ;;
	    *) panic_on_error "You should never get here! (Case *)" "show_modify_submenu"
	      ;;
	  esac
	  # We have modified variables from wizzard, so we must reset it!
	  wizzard_finished=0
    fi
  done
}

function show_control_submenu
{
  local CONTROL_COMMANDS=('StartVM - gui' 'StartVM - headless' 'Pause VM' 'Resume VM' 'Reset VM' 'ACPI shutdown' 'Power off VM')
  local vmUUID="$1" tmpR=0
  vmUUID="${vmUUID#*{}"
  vmUUID="{${vmUUID%\}*}}"

  while [[ $tmpR != -99 ]];
  do
    # Get VM state and extract it from the return string
    local VMstate=$(eval "VBoxManage showvminfo "$vmUUID" | grep "State:"")
    VMstate="${VMstate#*:}"
    VMstate="${VMstate% (*}"
    VMstate="${VMstate// /}"

    show_menu CONTROL_COMMANDS[@] "*Controlling VM: ${1%%|*}" "Choose your action: " "Back" "yes" "Current state: $VMstate"
    
    if [[ $REPLY = $((${#CONTROL_COMMANDS[@]}+1)) ]]; then
	  echo "nothing done"
	  tmpR=-99
    else
	  case "$MenuSel" in
	    'StartVM - gui')
	      if [[ "$VMstate" = "running" || "$VMstate" = "paused" ]]; then
		echo "Already running or paused! Use resume to unpause."
	      else
		VBoxManage startvm --type gui "$vmUUID"
	      fi
	      
	      ;;
	    'StartVM - headless') echo
	      if [[ "$VMstate" = "running" || "$VMstate" = "paused" ]]; then
		echo "Already running! Use resume to unpause."
		sleep 2
	      else
		VBoxManage startvm --type headless "$vmUUID"
	      fi
	      ;;
	    'Pause VM') echo
	      if [ "$VMstate" != "running" ]; then
		echo "VM not running, cannot pause!"
		sleep 2
	      else
		VBoxManage controlvm "$vmUUID" pause
	      fi
	      ;;
	    'Resume VM') echo
	      if [ "$VMstate" != "paused" ]; then
		echo "VM not paused, cannot resume!"
		sleep 2
	      else
		VBoxManage controlvm "$vmUUID" resume
	      fi
	      ;;
	    'Reset VM') echo
	      if [ "$VMstate" != "running" ]; then
		echo "VM not running, cannot reset!"
		sleep 2
	      else
		VBoxManage controlvm "$vmUUID" reset
	      fi
	      ;;
	    'ACPI shutdown') echo
	      if [[ "$VMstate" != "running" && "$VMstate" != "paused" ]]; then
		echo "VM not running, cannot send ACPI power button signal!"
		sleep 2
	      else
		VBoxManage controlvm "$vmUUID" acpipowerbutton
	      fi
	      ;;
	    'Power off VM') echo
	      if [[ "$VMstate" != "running" && "$VMstate" != "paused" ]]; then
		echo "VM not running, cannot turn it off!"
		sleep 2
	      else
		VBoxManage controlvm "$vmUUID" poweroff
	      fi
	      ;;
	    'Back')
	      unset VMstate
	      tmpR=-99
	      ;;
	    *) panic_on_error "Oooops ooops you should never get here! (MenuSel=$MenuSel)" "show_control_submenu"
	      ;;
	  esac
    fi
  done
}

function control_VM
{
  initialize_existing_VMs
  # Now VMSs contains list of names of Virtual machines and
  # tmpA contains "VMname|UUID" combination
  local curExistingVMSs=("${tmpA[@]}")
  unset VMSs
  unset tmpA
  
  initialize_existing_VMs "running"
  # tmpA now contains running (including paused) machines
  for (( i=0; i<=(${#curExistingVMSs[@]}-1); i++ ))
  do
    case "${tmpA[@]}" in *"${curExistingVMSs[$i]}"*) curExistingVMSs[$i]="${curExistingVMSs[$i]} -> running (or paused)" ;; esac
  done

  local tmpR=0
  while [[ $tmpR != -99 ]];
  do
    show_menu curExistingVMSs[@] "* Virtual machine control center" "Choose virtual machine to control: " "Back" "yes"
    if [[ $REPLY = $((${#curExistingVMSs[@]}+1)) ]]; then
	  echo "nothing done"
	  tmpR=-99
    else
	  show_control_submenu "${curExistingVMSs[($REPLY-1)]}"
	  tmpR=0
	    initialize_existing_VMs "running"
	    # tmpA now contains running (including paused) machines
	    for (( i=0; i<=(${#curExistingVMSs[@]}-1); i++ ))
	    do
	      case "${tmpA[@]}" in *"${curExistingVMSs[$i]}"*) curExistingVMSs[$i]="${curExistingVMSs[$i]} -> running" ;; esac
	    done

    fi
  done
}

function delete_VM
{
  # $1 - VMname; $2 - UUID
  local tstr="VM: $1"$'\n'"with UUID: $2 "$'\n'"All information, including attached disks, will be erased!"$'\n'
  show_menu YESNO[@] "*ERASE virtual machine?!" "Are you sure?! > " "no" "yes" "$tstr"
  if [[ "$MenuSel" == "yes" ]]; then
    local tmpcmd="VBoxManage unregistervm $2 --delete"
    eval $tmpcmd
  fi
}

function show_VM_properties
{
	  local cv fs i=0 curCTLs=""
	  local InfoCaptions=('-e "Memory size:"' '-e "VRAM size:"' '-e "CPU exec cap:"' '-e "Number of CPUs:"' '-e "Hardw. virt.ext:"' '-e "Guest OS:"' '-e "Chipset:"' '-e "Firmware:"')
	  readarray cv < <(eval "VBoxManage showvminfo "$2" | grep -i "${InfoCaptions[@]}"")
	  CurValues=("${cv[@]/$'\x0a'/}")	#This replaces new line character at the end of line! >>>  "${cv[@]/$'\x0a'/}"
	
	readarray fs < <(eval "VBoxManage showvminfo "$2" | grep 'Storage Controller'")
	for (( i=0; i<${#fs[@]}; i+=6 ));
	do
	  local CTname=${fs[$i]##* }
	  local CTtype=${fs[((i+1))]##* }
	  curCTLs="$curCTLs ${CTname/$'\x0a'/} (${CTtype/$'\x0a'/});"
	done

	clear
	echo "**********************************"
	echo "**  Virtual Machine properties  **"
	echo "**********************************"
	echo
	echo "Currently selected machine: $1 with UUID $2"
	echo "_____________________________"
	echo 
	echo "${CurValues[1]}"
	echo "${CurValues[2]}"
	echo "${CurValues[6]}""	${CurValues[3]}""	${CurValues[7]}"	# CPUs, Exec cap, HW virtualization
	echo "${CurValues[4]}""	${CurValues[5]}"				# Chipset & Firmware
	echo "${CurValues[0]}"							# Guest OS
	echo "Controllers:	$curCTLs"
	echo
	echo "! Any change you make takes effect immediately !"
	echo
}


# Main block
{
  # HERE STARTS "THE MAIN" :) PART OF SCRIPT
  set +vx
  echo "Initializing... please wait"
  initialize_constants
  wizzard_finished=0
  local mm=0
  
  while [[ $mm -ge 0 ]]; do
    if [ $wizzard_finished != 1 ]; then
      aMainMenu[1]='Create VM (disabled - run wizzard first!)'
    else
      aMainMenu[1]='Create VM (ready!)'
    fi
    show_menu aMainMenu[@] "*vboxGENIE Main menu" "Choose your action: " "Quit" "yes"
    mm=$REPLY
    case $mm in
      1) create_wizzard
	 echo FINISHED!
	 pause 3
	;;
      2) if [ $wizzard_finished = 1 ]; then
	    create_vm
	 else
	    echo "Please complete the VM wizzard first!"
	 fi
	;;
      3) modify_existing_VM
	;;
      4) control_VM
	;;
      5) mm=-1
	;;
    esac
  done

  echo "Thank you for using this script."

  exit 0
}
