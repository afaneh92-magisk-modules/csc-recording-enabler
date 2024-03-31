# Mount ro partitions
mount_name efs /efs '-o ro'
mount_name sec_efs /sec_efs '-o ro'
mount_name product /product '-o ro'
mount_name odm /odm '-o ro'
mount_name prism /prism '-o ro'
mount_name optics /optics '-o ro'

# Functions
get_omc_path() {
  local omc_code="$1"
  if [ -d "/product/omc/" ]; then
    if [ -d "/product/omc/${omc_code}/etc" ]; then
      omc_etcpath=/product/omc/${omc_code}/etc
    fi
    omc_root=/product/omc
    omc_path=/product/omc/${omc_code}/conf
  elif [ -d "/odm/omc/" ]; then
    if [ -d "/odm/omc/${omc_code}/etc" ]; then
      omc_etcpath=/odm/omc/${omc_code}/etc
    fi
    omc_root=/odm/omc
    omc_path=/odm/omc/${omc_code}/conf
  elif [ -d "/system/omc/" ]; then
    if [ -d "/system/omc/${omc_code}/etc" ]; then
      omc_etcpath=/system/omc/${omc_code}/etc
    fi
    omc_root=/system/omc
    omc_path=/system/omc/${omc_code}/conf
  elif [ -d "/product/etc/omc/" ]; then
    if [ -d "/product/etc/omc/${omc_code}/etc" ]; then
      omc_etcpath=/product/etc/omc/${omc_code}/etc
    fi
    omc_root=/product/etc/omc
    omc_path=/product/etc/omc/${omc_code}/conf
  elif [ -d "/odm/etc/omc/" ]; then
    if [ -d "/odm/etc/omc/${omc_code}/etc" ]; then
      omc_etcpath=/odm/etc/omc/${omc_code}/etc
    fi
    omc_root=/odm/etc/omc
    omc_path=/odm/etc/omc/${omc_code}/conf
  elif [ -d "/system/etc/omc/" ]; then
    if [ -d "/system/etc/omc/${omc_code}/etc" ]; then
      omc_etcpath=/system/etc/omc/${omc_code}/etc
    fi
    omc_root=/system/etc/omc
    omc_path=/system/etc/omc/${omc_code}/conf
  else
    if [ -d "/prism/etc/carriers/" ]; then
      if [ -d "/prism/etc/carriers/single/${omc_code}" ]; then
        omc_etcpath=/prism/etc/carriers/single/${omc_code}
      elif [ -d "/prism/etc/carriers/${omc_code}" ]; then
        omc_etcpath=/prism/etc/carriers/${omc_code}
      fi
      if [ -d "/optics/configs/carriers/" ]; then
        if [ -d "/optics/configs/carriers/single/" ]; then
           omc_root=/optics/configs/carriers/single
           omc_path=/optics/configs/carriers/single/${omc_code}/conf
           if [ -d "/optics/configs/carriers/single/${omc_code}/conf/system/" ]; then
             mdc_path=/optics/configs/carriers/single/${omc_code}/conf/system
           fi
        else
           omc_root=/optics/configs/carriers
           omc_path=/optics/configs/carriers/${omc_code}/conf
           if [ -d "/optics/configs/carriers/${omc_code}/conf/system/" ]; then
             mdc_path=/optics/configs/carriers/${omc_code}/conf/system
           fi
        fi
      fi
    fi
  fi
}

add_csc_feature() {
  feature=$1
  value=$2
  lineNumber=0
  lineNumber=`sed -n "/<${feature}>.*<\/${feature}>/=" $MODPATH/$i`
  if [ $lineNumber > 0 ] ; then
    ui_print "- Found feature $feature in line $lineNumber and changing it to ${value} in $i"
    sed -i "${lineNumber} c<${feature}>${value}<\/${feature}>" $MODPATH/$i
  else
    ui_print "- Adding feature $feature to the feature set in $i"
    sed -i "/<\/FeatureSet>/i \   \ <${feature}>${value}<\/${feature}>" $MODPATH/$i
  fi
}

# Paths
path_mps="/efs/imei/mps_code.dat";
path_mps2="/sec_efs/imei/mps_code.dat";

# Your script starts here
omc_code=`cat ${path_mps} 2>/dev/null`;
[ ! -z "$omc_code" ] || omc_code=`cat ${path_mps2} 2>/dev/null`;

get_omc_path ${omc_code}

[ -z "$mdc_path" ] || omc_path=$mdc_path
original_files=`find $omc_path -type f -name 'cscfeature.xml'`

ui_print "- Copy omc files"
chmod 755 $MODPATH/omc-decoder
mkdir -p $MODPATH/$omc_path
cp -aR $omc_path/* $MODPATH/$omc_path
ui_print "- Start decodeing..."
xml_pattern="<?xml version=[\"']1.0[\"'] encoding=[\"']UTF-8[\"']?>"
for i in $original_files; do
  if `$MODPATH/omc-decoder -d $MODPATH/$i $MODPATH/$i` ; then
    ui_print "- Successfully decoded $i!"
  else
    ui_print "- Not decoded $i!"
  fi
  # Add CSC Features if decoded
  if `grep -ixq "$xml_pattern" $MODPATH/$i` ; then
    add_csc_feature CscFeature_VoiceCall_ConfigRecording RecordingAllowed
  fi
done

# Change Module OMC Path
sed -i "s~omc\_path~$omc_path~g" $MODPATH/post-fs-data.sh;

# Set executable permissions
set_perm_recursive "$MODPATH" 0 0 0755 0644

# Clean up files
rm -rf $MODPATH/omc-decoder
