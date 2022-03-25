SKIPUNZIP=1

# Extract files
ui_print "- Extracting module files"
unzip -o "$ZIPFILE" module.prop omc-decoder.jar post-fs-data.sh -d $MODPATH >&2

# Functions
run_jar() {
    local dalvikvm file main 
    #Inspired in the osm0sis method
    if dalvikvm -showversion >/dev/null; then
       dalvikvm=dalvikvm
    elif /system/bin/dalvikvm -showversion >/dev/null; then 
       dalvikvm=/system/bin/dalvikvm
    else
       echo "CANT LOAD DALVIKVM " && return
    fi
    file="$1"
    unzip -o "$file" "META-INF/MANIFEST.MF" -p > "/data/main.tmp"
    main=$(cat /data/main.tmp | grep -m1 "^Main-Class:" | cut -f2 -d: | tr -d " " | dos2unix)
    rm -f /data/main.tmp
    if [ -z "$main" ]; then
       echo "Cant get main: $file " && return
    fi
    shift 1
    $dalvikvm -Djava.io.tmpdir=. -Xnodex2oat -Xnoimage-dex2oat -cp "$file" $main "$@" 2>/dev/null \ || $dalvikvm -Djava.io.tmpdir=. -Xnoimage-dex2oat -cp "$file" $main "$@"
}

add_csc_feature() {
  feature=$1
  value=$2
  lineNumber=0
  lineNumber=`sed -n "/<${feature}>.*<\/${feature}>/=" $MODPATH/$i`
  if [ $lineNumber > 0 ] ; then
    echo "- Found feature $feature in line $lineNumber and changing it to ${value} in $i"
    sed -i "${lineNumber} c<${feature}>${value}<\/${feature}>" $MODPATH/$i
  else
    echo "- Adding feature $feature to the feature set in $i"
    sed -i "/<\/FeatureSet>/i \   \ <${feature}>${value}<\/${feature}>" $MODPATH/$i
  fi
}

# Paths
omc_path=`getprop persist.sys.omc_path`
mdc_path=`getprop mdc.system.path`
[ -z "$mdc_path" ] || omc_path=$mdc_path
original_files=`find $omc_path -type f -name 'cscfeature.xml'`

# Your script starts here
ui_print "- Copy omc files"
mkdir -p $MODPATH/$omc_path
cp -aR $omc_path/* $MODPATH/$omc_path
ui_print "- Start decodeing..."
xml_pattern="<?xml version=[\"']1.0[\"'] encoding=[\"']UTF-8[\"']?>"
for i in $original_files; do
  if `run_jar "$MODPATH/omc-decoder.jar" -i $MODPATH/$i -o $MODPATH/$i` ; then
    ui_print "- Not decoded $i!"
  else
    ui_print "- Successfully decoded $i!"
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
rm -rf $MODPATH/omc-decoder.jar
