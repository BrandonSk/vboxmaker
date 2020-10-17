#!/bin/bash
## Created by: Branislav Susila (C) 2014
##
## This script collects information and then creates a virtual machine.
## 
## VirtualBox and Extension pack must be installed before running this script!
## There is only limited exception handling. For some expert features you are
## expected to know what you are doing!
##
## For some on/off options a file called vbx_onoff must be present in the
## same directory as this script, otherwise these options will be skipped!
##
## Script comes with absolutely no warranty - use at your own risk ;)
##
## Feel free to re-distribute and/or modify the script. I only ask you keep
## the reference to the original script and this text at the beginning in it.
##

## Functions

function initialize_ostypes
{
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
    OSTYPES=$( printf "%s" "${tmpA[@]} " )
    unset fs
    unset tmpA
}

function show_summary
{
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
  echo "SATA ctl name: $SATAname  Type: $SATAtype"
  echo "Number of drives: $DISKcount   Number of NICs: $NICcount"
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

# Collecting information

  function get_vm_name
  {
    # Get machine name
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
      oIFS=$IFS
      IFS=';' read -a arrIN <<< "$1"
      IFS=$oIFS
      echo
      echo "<<< ${arrIN[0]} >>>"
      echo "${arrIN[2]}"
      select rusure in $YESNO; do
	if [[ -n $rusure ]]; then
	  if [[ $rusure == "yes" ]]; then
	    OTHoptions="$OTHoptions ${arrIN[1]} on "
	  fi
	  break
	fi
      done

    }
    
    function get_other_settings
    {
      show_summary
      echo
      echo "Now we will configure bunch of on/off settings: "
      echo
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
	echo "Skipping this configuration part."
	sleep 3
      fi
    }
    
    function define_ostype
      {
	show_summary
	echo "Please select the operating system you intend to use: "
	select OStype in $OSTYPES; do
	  if [[ -n $OStype ]]; then
	    break
	  fi
	done
      }


  # DISK related functions
    function get_hdd_details
    {
	repeat=1
	while [ $repeat -eq 1 ] ; do
	  repeat=0
	  echo
	  echo "Are we creating"
	  echo "    1) virtual disk file"
	  echo "    2) RAW access to partition"
	  echo "? (Please enter 1 or 2)"
	  read AccessType
	  case "$AccessType" in
	      '1') echo
		    rpt2=1
		    VDIsize=0		# also determines, whether it is existing VDI (0) or new (>0)
		    while [ $rpt2 -eq 1 ] ; do
		      rpt2=0
		      echo -n "Enter the name of the virtual disk file (without vdi extenstion): "
		      read VDIname
		      VDIname="$VDIname.vdi"
		      fullpath="$VMPath/$VDIname"
		      
		      test -e "$fullpath"
		      if [ $? -eq 1 ] ; then
			echo -n "File does not exist. Create a new VDI file? (y-yes; other/no): "
			read rusure
			if [ "$rusure" != "y" ] ; then
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
			fi
		      fi
		      
		    done
		    DISKsize[i]="--size $VDIsize"
		    DISKmedium[i]="\"$fullpath\""
		    #DISKdevice[i]="dummy"	# dummy, just to keep arrays aligned
		    ;;
	      '2') echo
		    echo "This option is for experts only! Are you sure?"
		    echo "Pre-requisites:"
		    echo "    1) You must have write rights to disk devices"
		    echo "    2) know to which disks and partitions to enable RAW access."
		    echo
		    echo -n "Do you want to continue (y-yes; other-no)? "
		    read rusure
		    if [ "$rusure" != "y" ] ; then
		      repeat=1
		    else
		      echo "OK" # Here goes the whole RAW access stuff
		      echo -n "Enter name for the RAW disk access definition file (without extension): "
		      read VDIname
		      VDIname="$VDIname.vmdk"
		      fullpath="$VMPath/$VDIname"
			# ADD CHECK FOR EMPTY STRING AND FOR EXISTING FILE - should never exist, as the machine will be created new ;)
		      echo
		      echo -n "Enter physical disk device (e.g. /dev/sdb): "
		      read DISKdevice
			# ADD CHECK THAT DISK DEVICE EXISTS
		      echo
		      echo "Enter partition numbers, which you want to become accessible (e.g. 1,2,5): "
		      read DISKpartition
			# ADD CHECK FOR CORRECT PATTERN
		      DISKsize[i]="-rawdisk $DISKdevice -partitions $DISKpartition"
		      DISKmedium[i]="\"$fullpath\""
		      DISKtype[i]="r"	# This is to distinguish between raw and virtual disks
		    fi
		    ;;
	      *) repeat=1 ;;
	  esac
	done
    }
    function get_dvd_details
    {
	repeat=1
	while [ $repeat -eq 1 ] ; do
	  echo "Enter path to ISO file to attach or type leave blank for empty drive:"
	  read Medium
	  repeat=0
	  if [ -z "$Medium" ] ; then
	    DISKmedium[i]="\"emptydrive\""
	  else
	    if [ -e $Medium ] ; then
	      DISKmedium[i]="\"$Medium\""
	    else
	      echo "Ooopla. The file you specified does not exist. Please try again (full path)."
	      repeat=1
	    fi
	  fi
	done
	DISKsize[i]=0	# dummy, just to keep arrays aligned
    }
    function get_fdd_details
    {
	echo "FDD not yet supported, sorry"
    }
    function specify_disk_type
    {
	# Select disk type
	echo "Please specify disk type (h-HDD; d-DVD; f-FDD): "
	select DT in h d f; do
	  if [[ -n $DT ]]; then
	    DISKtype[i]="$DT"
	    break
	  fi
	done
	# Later in HDD definition we may replace the 'h' with 'r' for RAW access disks
	case ${DISKtype[i]} in
	    'h') get_hdd_details ;;
	    'd') get_dvd_details ;;
	    'f') get_fdd_details ;;
	    *) echo "Oooops ooops, you should never get here!"; echo "Panic! Exiting... (ref. specify_disk_type)"; exit 1 ;;
	esac
    }
    function collect_disks_information
    {
      for (( i=0; i<=("$DISKcount"-1); i++ ))
      do
	show_summary
	echo
	echo "Now collecting information for disk #$[$i+1]:"
	
	specify_disk_type
      done
    }
    function get_disk_count
    {
      DISKcount=0
      while [ $DISKcount -le 0 ] ; do
	echo -n "How many disks (including HDD, DVD and FDD) would you like to use?: "
	read DISKcount
	case $DISKcount in
	    ''|*[!0-9]*) DISKcount=0 ;;
	    *) echo OK ;;
	esac
      done
    }

  # NIC related functions
    function specify_nic_type
    {
      # Available NI cards
      NICS=('Am79C970A' 'Am79C973' '82540EM' '82543GC' '82545EM' 'virtio')
      echo "First 2 should work in all systems, 3-5 are Intel emulation, 6 is not supported by this script"
      select NT in "${NICS[@]}"; do
	NICtype[i]="$NT"
	if [[ -n $NT ]]; then
	  break
	fi
      done
      
      echo "Specify mode in which NIC$i (type ${NICtype[i]}) will operate:"
      NICS=('none' 'null' 'nat' 'bridged' 'intnet' 'hostonly' 'generic')
      select NT in "${NICS[@]}"; do
	NICmode[i]="$NT"
	NICmodeID[i]="$REPLY"
	if [[ -n $NT ]]; then
	  break
	fi
      done
      
      case "${NICmodeID[i]}" in
	1) NICother[i]="" ;;
	2) NICother[i]="" ;;
	3) echo
	    echo -n "Enter name of NAT network: "
	    read tmpS1
	    echo -n "Enter the network interface in format (a.b.c.0; e.g. 192.168.123.0): "
	    read tmpS2
	    echo "Choose network mask (sorry, subnets not available at the moment: "
	    select tmpcmd in "255.0.0.0" "255.255.0.0" "255.255.255.0"; do
	      if [[ -n $tmpcmd ]]; then
		tmpS3=$[$REPLY*8]
		break
	      fi
	    done
	    echo
	    echo "Enable DHCP on the Nat network?"
	    select tmpcmd in $YESNO; do
	      if [[ -n $tmpcmd ]]; then
		if [[ $REPLY -eq 1 ]]; then
		  tmpcmd="-h on"
		else
		  tmpcmd=""
		fi
		break
	      fi
	    done
	    NICother[i]="-t $tmpS1 -n \"$tmpS2/$tmpS3\" -e $tmpcmd"
	    ;;
	4) echo "Select to which HW NIC the bridged adapter will connect to: "
	    tmpS1=`ifconfig | grep 'eth' | awk '{print $1}'`
	    tmpS2=`ifconfig | grep 'wlan' | awk '{print $1}'`
	    tmpS1="${tmpS1[@]} ${tmpS2[@]}"
	    select NCo in ${tmpS1[@]}; do
	      NICother[i]="--bridgeadapter$[$i+1]"
	      if [[ -n $NCo ]]; then
		echo "Here $NCo"
		NICother[i]="${NICother[i]} $NCo"
		echo "There ${NICother[i]}"
		break
	      fi
	    done
	    ;;
	5) echo
	    echo -n "Enter name of internal network: "
	    read tmpS1
	    NICother[i]="--intnet$[$i+1] $tmpS1" ;;
	6) echo "Select to which host's HW NIC will be used for host-only network: "
	    tmpS1=`ifconfig | grep 'eth' | awk '{print $1}'`
	    tmpS2=`ifconfig | grep 'wlan' | awk '{print $1}'`
	    tmpS1="none ${tmpS1[@]} ${tmpS2[@]}"
	    select NCo in ${tmpS1[@]}; do
	      NICother[i]="--hostonlyadapter$[$i+1] $NCo"
	      if [[ -n $NCo ]]; then
		break
	      fi
	    done	    
	    ;;
	7) NICother[i]=""
	  echo
	  echo "*************   OK, BUT...   ********************"
	  echo "[generic] has LIMITED support at this moment!"
	  echo "Manual configuration of properties must be done!"
	  echo "*************************************************"
	  sleep 3
	  ;;
	*) echo "Oooops ooops! You should never get here! Panic! Exiting... (ref. specify_nic_type)"
	    exit 1
	    ;;
      esac    
	  
    }
    function get_nic_count
    {
      show_summary
      echo
      NICcount=31
      while [ $NICcount -ge 31 ]; do
	echo -n "How many network interfaces (0-30)? : "
	read NICcount
	if [[ $NICcount -le 0 || $NICcount -ge 31 ]]; then
	  NICcount=31
	fi
      done
    }
    function collect_nics_information
    {
      for (( i=0; i<=("$NICcount"-1); i++ ))
      do
	show_summary
	echo
	echo "Now configuring information for NIC #$[$i+1]"
	echo
	specify_nic_type
      done
    }
  # CPU, RAM & MB
    function define_cpu_parameters
    {
      #Get CPU count
      show_summary
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
      show_summary
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
      show_summary
      echo "Enable HW virtualization? "
      select HWvi in $YESNO; do
	if [[ -n $HWvi ]]; then
	  break
	fi
      done
    }
    function define_mb_parameters
    {
      # Chipset
      show_summary
      echo "Please select the chipset you want to emulate: "
      select Chipset in $CHIPSETS; do
	if [[ -n $Chipset ]]; then
	  break
	fi
      done
      
      # Firmware
      show_summary
      echo "Please select the firmware you want to emulate: "
      select Firmware in $FIRMWARES; do
	if [[ -n $Firmware ]]; then
	  break
	fi
      done
    }
    function get_ram_size
    {
      # Get RAM size
      show_summary
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
    function get_SATA_controller_type
    {
      select SATAtype in $SATATYPES; do
	if [[ -n $SATAtype ]]; then
	  break
	fi
      done
    }

  # Video
    function define_vga_parameters
    {
    # VGA size
    show_summary
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
    echo "Do you want to enable 3D accelleration?"
    select tmpcmd in $YESNO; do
      if [[ -n $tmpcmd ]]; then
	if [[ $REPLY -eq 1 ]]; then
	  Accel3d="--accelerate3d on"
	else
	  Accel3d=""
	fi
	break
      fi
    done
  }

  function define_boot_order()
  {
    bootorder=""
    for (( i=1; i<=4; i++ ))
      do
	show_summary
	echo
	echo "Please select boot device #$i:"
	select btx in $BOOTDEVICES; do
	  if [[ -n $btx ]]; then
	    bootorder="$bootorder --boot$i $btx"
	    break
	  fi
	done
      done
  }



function run_command
{
  if [[ -n $2 ]]; then
    echo "Executing: $2"
  fi
  
  if [[ -n "$DumpComm" ]]; then
    echo "# $2" >> "$DumpComm"
    echo "$1" >> "$DumpComm"
  fi
  
  eval $1
  ES=$?
  
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
# $1 - index; $2 - disk type; $3 - disk size; $4 - disk medium
{
  echo "Disk #$1: type[$2], size[$3], medium[$4]"
  case "$2" in
    f) echo "Sorry, FDD not yet supported" ;;
    d) desc="Attaching DVD drive to VM"
	tmpcmd="VBoxManage storageattach $VMname --storagectl $SATAname --port $1"
	tmpcmd="$tmpcmd --device 0 --type dvddrive --medium $4"
	run_command "$tmpcmd" "$desc"
      ;;
    [hr]) if [[ $2 == "h" ]]; then
		  desc="Creating VDI file"
		  tmpS1="createhd --filename"
	      else
		  desc="Creating VDMK file for RAW access"
		  tmpS1="internalcommands createrawvmdk -filename"
	      fi
	tmpcmd="VBoxManage $tmpS1 $4 $3"
	run_command "$tmpcmd" "$desc"
	desc="Attaching disk to VM"
	tmpcmd="VBoxManage storageattach $VMname --storagectl $SATAname --port $1"
	tmpcmd="$tmpcmd --device 0 --type hdd --medium $4"
	run_command "$tmpcmd" "$desc"
      ;;
    #'r') desc="Creating VDMK file for RAW access"
	#tmpcmd="VBoxManage internalcommands createrawvmdk -filename \"$4\" $3"
	#run_command "$tmpcmd" "$desc"
	#desc="Attaching RAW disk to VM"
	#tmpcmd="VBoxManage storageattach $VMname --storagectl $SATAname --port $1"
	#tmpcmd="$tmpcmd --device 0 --type hdd --medium \"$4\""
	#run_command "$tmpcmd" "$desc"
      #;;
    *) echo "Panic! You should never get here!"
      echo "Exiting... Details: add_disk $1, $2, $3, $4"
      exit 2
      ;;
  esac
}

function add_disks()
{
  for (( i=0; i<=($DISKcount-1); i++ ))
  do
    add_disk $i ${DISKtype[i]} "${DISKsize[i]}" "${DISKmedium[i]}"
  done
}

function add_nic()
{
  tmpcmd="VBoxManage modifyvm $VMname --nic$1 $3 --nictype$1 $2 $4"
  desc="Adding NIC #$1 to the VM"
  run_command "$tmpcmd" "$desc"
}

function add_nics()
{
  for (( i=0; i<=("$NICcount"-1); i++ ))
  do
    add_nic $[$i+1] ${NICtype[i]} ${NICmode[i]} "${NICother[i]}"
  done
}

function make_dump_script()
{
  # Defines, whether creation commands are also dumped to a shell script file
  
  echo "Do you want to dump the creation commands into a file?"
  echo "(Hint: You may later just make the file a shell script and re-run to recreate the VM.)"
  select rusure in $YESNO;
  do
    if [[ -n "$rusure" ]]; then
      DumpComm="$rusure"
      break
    fi
  done
  if [[ "$DumpComm" == "yes" ]]; then
    DumpComm="$CWD/$VMname-vbox-create.sh"
    if [[ -e "$DumpComm" ]]; then
      echo
      echo "File $DumpComm already exists."
      echo "Overwrite?"
      select rusure in $YESNO;
      do
	if [[ -n "$rusure" ]]; then
	  if [[ "$rusure" == "no" ]]; then
	    break
	  fi
	fi
      done
    fi
    echo "#!/bin/bash" > "$DumpComm"
    echo "# Created by VirtualBoxMaker script" >> "$DumpComm"
    echo "#" >> "$DumpComm"
  else
    DumpComm=""
  fi
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
  # Disks
    show_summary
    echo "This scripts automatically creates a SATA controller."
    echo "Please select the type of SATA controller to emulate:"
    get_SATA_controller_type
    get_disk_count 
    collect_disks_information
  # Boot order
    define_boot_order
  # Network Interface Cards
    get_nic_count
    collect_nics_information
  # Operating system selection
    define_ostype
  # Other settings (e.g. Remote Desktop)
    get_other_settings

  show_summary
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
# Register VM
  desc="Registering VM"
  tmpcmd="VBoxManage createvm --name $VMname --register"
  run_command "$tmpcmd" "$desc"
  
# CPU
  desc="Defining CPU"
  tmpcmd="VBoxManage modifyvm $VMname --cpus $CPUcount --cpuexecutioncap $CPUexcap"
  if [[ $HWvi != "no" ]]; then
    tmpcmd="$tmpcmd --hwvirtex on"
  fi
  run_command "$tmpcmd" "$desc"
  
# Motherboard
  desc="Configuring motherboard"
  tmpcmd="VBoxManage modifyvm $VMname --chipset $Chipset --firmware $Firmware"
  run_command "$tmpcmd" "$desc"

# Memory
  desc="Configuring memory"
  tmpcmd="VBoxManage modifyvm $VMname --memory $RAMsize"
  run_command "$tmpcmd" "$desc"

# Video
  desc="Configuring video settings"
  tmpcmd="VBoxManage modifyvm $VMname --vram $VGAsize"
  if [[ -n $Accel3d ]]; then
    tmpcmd="$tmpcmd $Accel3d"
  fi
  run_command "$tmpcmd" "$desc"

# HDD, DVD, FDD
  desc="Adding sata controller"
  tmpcmd="VBoxManage storagectl $VMname --name $SATAname --add sata --controller $SATAtype"
  run_command "$tmpcmd" "$desc"
  #Now loop through the discs
  add_disks
  
# NICs
  add_nics

# Add other options
  desc="Configuring on/off options"
  tmpcmd="VBoxManage modifyvm $VMname $OTHoptions"
  run_command "$tmpcmd" "$desc" 

# Boot order
  desc="Setting boot order"
  tmpcmd="VBoxManage modifyvm $VMname $bootorder"
  run_command "$tmpcmd" "$desc" 

# OS type
  desc="Configuring OS type"
  tmpcmd="VBoxManage modifyvm $VMname --ostype $OStype"
  run_command "$tmpcmd" "$desc" 
  
# Make dump script executable
  if [[ -n "$DumpComm" ]]; then
    chmod og+x "$DumpComm"
  fi
}

function show_menu
{
  show_summary
  echo
  echo "Main menu:"
  echo
  select mm in "${MAINMENU[@]}"; do
    if [[ -n $mm ]]; then
      mm=$REPLY
      break
    fi
  done
}

function populate_VMs
{
  tmpcmd="VBoxManage list vms"
  echo `$tmpcmd`
  echo
  echo Press any key
  read
}

function list_VMs
{
  clear
  echo "List of available VMs:"
  echo
  populate_VMs
}

## Variables and Constants

CHIPSETS="ich9 piix3"
FIRMWARES="bios efi efi32 efi64"
#OSTYPES='Other Windows31 Windows95 Windows98 WindowsMe WindowsNT4 Windows2000 WindowsXP WindowsXP_64 
#	Windows2003 Windows2003_64 WindowsVista WindowsVista_64 Windows2008 Windows2008_64 Windows7 Windows7_64 
#	Windows8 Windows8_64 Windows2012_64 WindowsNT 
#	Linux22 Linux24 Linux24_64 Linux26 Linux26_64 ArchLinux ArchLinux_64 Debian Debian_64 OpenSUSE OpenSUSE_64 
#	Fedora Fedora_64 Gentoo Gentoo_64 Mandriva Mandriva_64 RedHat RedHat_64 Turbolinux Turbolinux_64 
#	Ubuntu Ubuntu_64 Xandros Xandros_64 Oracle Oracle_64 Linux 
#	Solaris Solaris_64 OpenSolaris OpenSolaris_64 Solaris11_64 FreeBSD FreeBSD_64 OpenBSD OpenBSD_64 NetBSD NetBSD_64 
#	OS2Warp3 OS2Warp4 OS2Warp45 OS2eCS OS2 MacOS MacOS_64 DOS Netware L4 QNX JRockitVE'
SATATYPES="LSILogic LSILogicSAS BusLogic IntelAHCI PIIX3 PIIX4 ICH6 I82078"
YESNO="yes no"
#CPUPLATFORM="Intel AMD"
BOOTDEVICES="none floppy dvd disk net"
MAINMENU=('Run creation wizzard' 'Create VM based on wizzard values' 'Show existing VMs' 'Delete a VM (will show list first)' 'Quit')

UName="$USER"
SATAname="SATA_controller"

VMPath=""
CWD=$(pwd)

# HERE STARTS "THE MAIN" :) PART OF SCRIPT
set +vx
echo "Initializing... please wait"
mm=99
  #Initialize OSTYPES
    initialize_ostypes
    
while [[ $mm -ge 0 ]]; do
  show_menu
  case $mm in
    1) create_wizzard
      ;;
    2) create_vm
      ;;
    3) list_VMs
      ;;
    4) ;;
    5) mm=-1
      ;;
  esac
done

echo "Thank you for using this script."

exit 0
