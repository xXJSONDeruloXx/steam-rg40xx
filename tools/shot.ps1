param([string]$Out = "C:\Users\kurt\steam-rg40xx\fb.png")
adb -s 0c001080c69249221d2 shell "cat /dev/fb0 > /tmp/fb.raw" | Out-Null
adb -s 0c001080c69249221d2 pull /tmp/fb.raw C:\Users\kurt\steam-rg40xx\fb.raw | Out-Null
python -c "from PIL import Image; d=open(r'C:\Users\kurt\steam-rg40xx\fb.raw','rb').read()[:640*480*4]; Image.frombuffer('RGBA',(640,480),d,'raw','BGRA',0,1).convert('RGB').save(r'$Out')"
