# AnyKernel3 Ramdisk Mod Script
# osm0sis @ xda-developers
#
# E404R kernel custom installer by 113
# What are you looking for ?

properties() { '
kernel.string=E404R Kernel by Project 113
do.modules=0
do.systemless=1
'; }

devicecheck() {
  [[ "$(file_getprop anykernel.sh devicecheck)" == 1 ]] || return 1;
  local device devicename match product testname vendordevice vendorproduct;
  device=$(getprop ro.product.device 2>/dev/null);
  product=$(getprop ro.build.product 2>/dev/null);
  vendordevice=$(getprop ro.product.vendor.device 2>/dev/null);
  vendorproduct=$(getprop ro.vendor.product.device 2>/dev/null);
  for testname in $(grep 'devicename' anykernel.sh | cut -d= -f2-); do
    for devicename in $device $product $vendordevice $vendorproduct; do
      if [[ "$devicename" == *"$testname"* ]]; then
        match=1
        break
      fi
    done
  done
  if [[ ! "$match" ]]; then
    abort " " " Unsupported device. Aborting...";
  fi
}

select_option() {
  ui_print " - $1 :"
  ui_print "  (Vol +) $2"
  ui_print "  (Vol -) $3"

  SELECT_RESULT=""
  while true; do
    ev=$(getevent -lt 2>/dev/null | grep -m1 "KEY_VOLUME")
    case "$ev" in
      *KEY_VOLUMEUP*)
        ui_print "  Selected : $2" " "
        SELECT_RESULT="$2"
        break
        ;;
      *KEY_VOLUMEDOWN*)
        ui_print "  Selected : $3" " "
        SELECT_RESULT="$3"
        break
        ;;
    esac
  done
  sleep 0.5
  echo "$SELECT_RESULT"
}

configure_manual() {
  # ROM selection
  select_option "ROM/DTBO Type" "AOSP/CLO" "MIUI/HyperOS"
  rom_sel="$SELECT_RESULT"
  case "$rom_sel" in
    *AOSP*|*CLO*)
      [ "$oplus" != "1" ] && rom="rom_aosp"
      dtbo="dtbo_def"
      ;;
    *MIUI*|*HyperOS*)
      [ "$oplus" != "1" ] && rom="rom_oem"
      dtbo="dtbo_oem"
      ;;
  esac

  # KernelSU selection
  select_option "KernelSU Root" "KernelSU" "Default"
  root_sel="$SELECT_RESULT"
  case "$root_sel" in
    *KernelSU*)
      root="root_ksu"
      select_option "SUSFS4KSU Support" "Enabled" "Disabled"
      susfs_sel="$SELECT_RESULT"
      case "$susfs_sel" in
        *Enabled*) susfs="susfs" ;;
        *) susfs="nosusfs" ;;
      esac
      ;;
    *)
      root="root_noksu"
      susfs="nosusfs"
      ;;
  esac

  # DTB selection
  select_option "DTB CPU Frequency" "EFFCPU" "Default"
  dtb_sel="$SELECT_RESULT"
  case "$dtb_sel" in
    *EFFCPU*) dtb="dtb_effcpu" ;;
    *) dtb="dtb_def" ;;
  esac

  # Battery profile (Alioth only)
  if [[ "$devicename" == "alioth" ]]; then
    select_option "Battery Profile" "5000mAh" "Default"
    batt_sel="$SELECT_RESULT"
    case "$batt_sel" in
      *5000*) batt="batt_5k" ;;
      *) batt="batt_def" ;;
    esac
  else
    batt="batt_def"
  fi

  ui_print " Manual configuration done !" " "
  sleep 0.5
}

configure_auto() {
  sleep 0.5
  miprops="$(file_getprop /vendor/build.prop "ro.vendor.miui.build.region" 2>/dev/null)"
  if [[ -z "$miprops" ]]; then
    miprops="$(file_getprop /product/etc/build.prop "ro.miui.build.region" 2>/dev/null)"
  fi
  case "$miprops" in
    cn|in|ru|id|eu|tr|tw|gb|global|mx|jp|kr|lm|cl|mi)
      ui_print "--> Miui/HyperOS ROM detected, configuring..."
      rom="rom_oem"
      dtbo="dtbo_oem"
      ;;
    *)
      if [[ "$oplus" != "1" ]]; then
        ui_print "--> AOSP/CLO ROM detected, configuring..."
        rom="rom_aosp"
      else
        ui_print "--> Oplus Port ROM detected, configuring..."
      fi
      dtbo="dtbo_def"
      ;;
  esac

  sleep 0.5
  if [[ "$ZIPFILE" == *ksu* ]] || ([[ -d /data/adb/ksu ]] && [[ -f /data/adb/ksud ]]); then
    ui_print "--> KernelSU is detected, configuring..."
    root="root_ksu"
    sleep 0.5
    if [[ -d /data/adb/susfs4ksu ]] && [[ -d /data/adb/modules/susfs4ksu ]]; then
      ui_print "--> SUSFS4KSU is detected, configuring..."
      susfs="susfs"
    else
      ui_print "--> SUSFS4KSU not detected, skipping..."
      susfs="nosusfs"
    fi
  else
    ui_print "--> KernelSU not detected, skipping..."
    ui_print "--> SUSFS4KSU also skipped as well..."
    root="root_noksu"
    susfs="nosusfs"
  fi

  sleep 0.5
  if [[ "$ZIPFILE" == *effcpu* || "$ZIPFILE" == *EFFCPU* ]]; then
    ui_print "--> EFFCPUFreq is detected, configuring..."
    dtb="dtb_effcpu"
  else
    ui_print "--> EFFCPUFreq not detected, skipping..."
    dtb="dtb_def"
  fi

  sleep 0.5
  if [[ "$devicename" == "alioth" ]]; then
    if [[ "$ZIPFILE" == *5k* || "$ZIPFILE" == *5K* ]]; then
      ui_print "--> 5K battery profile detected, configuring..."
      batt="batt_5k"
    else
      ui_print "--> Stock Alioth battery profile, configuring..."
      batt="batt_def"
    fi
  else
    batt="batt_def"
  fi

  ui_print " " " Auto configuration done !" " "
  sleep 0.5
}

choose_config_mode() {
  ui_print " " " Select Kernel Configuration :"
  ui_print "  (Vol +) Manual Configuration "
  ui_print "  (Vol -) Auto Configuration " " "
  while true; do
    ev=$(getevent -lt 2>/dev/null | grep -m1 "KEY_VOLUME.*DOWN")
    case $ev in
      *KEY_VOLUMEUP*) configure_manual; break ;;
      *KEY_VOLUMEDOWN*) configure_auto; break ;;
    esac
  done
}

#
# Install begins here
# 

devicename=munch;
case "$devicename" in
  munch|alioth|pipa)
    is_slot_device=1;
  ;;
  apollo|lmi)
    is_slot_device=0;
  ;;
esac
block=/dev/block/bootdevice/by-name/boot
ramdisk_compression=auto
patch_vbmeta_flag=auto

. tools/ak3-core.sh

if [[ -f /vendor/OemPorts10T.prop ]] ||
  [[ -f /vendor/etc/init/OemPorts10T.rc ]]; then
  ui_print " ! Detected OPLUS Port ROM by Dandaa !"
  ui_print " ! Manual Configuration is Recommended !"
  ui_print " Note : Port ROM Usually Need KernelSU Root !"
  rom="rom_port"
  oplus=1
else
  oplus=0
  devicecheck
fi

sleep 0.5
if [[ "$SIDELOAD" == "1" ]]; then
  ui_print " " " ! Sideloading Detected, Overriding to Manual Configuration !"
  configure_manual
else
  choose_config_mode
fi

if [[ "$susfs" == "susfs" ]]; then
  rm -f *-NOSUSFS-Image
else
  rm -f *-SUSFS-Image
fi

mv *-Image $home/Image
mv *-dtb $home/dtb
mv *-dtbo.img $home/dtbo.img

dump_boot

ui_print "--> Applying cmdline..."
ui_print " e404_args=$root,$susfs,$rom,$dtbo,$dtb,$batt"
patch_cmdline "e404_args" "e404_args=$root,$susfs,$rom,$dtbo,$dtb,$batt"

ui_print "--> Installing... "

write_boot

if [[ $is_slot_device == 1 ]]; then
 ui_print "--> Installing to A/B slot... "
  block=/dev/block/bootdevice/by-name/vendor_boot
  ramdisk_compression=auto
  patch_vbmeta_flag=auto
  reset_ak
  dump_boot
  write_boot
fi

if [[ ! -f /vendor/etc/task_profiles.json ]]; then
	ui_print " " " Note : Uclamp Task Profile Not Found ! " " "
fi

ui_print " " " --- Install Done ! --- "