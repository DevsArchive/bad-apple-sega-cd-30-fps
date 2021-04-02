@echo off

..\bin\asm68k.exe /p /q fmv1bpp\main.asm, _files\FMVMAIN.MCD,,fmv1bpp\main.lst
..\bin\asm68k.exe /p /q fmv1bpp\sub.asm, _files\FMVSUB.SCD,,fmv1bpp\sub.lst

..\bin\asm68k.exe /p /q mainprg\mainprg.asm, _files\MAINPRG.MCD,,mainprg\mainprg.lst

..\bin\mkisofs.exe -quiet -abstract ABS.TXT -biblio BIB.TXT -copyright CPY.TXT -A "RALAKIMUS" -V "BAD_APPLE" -publisher "RALAKIMUS" -p "RALAKIMUS" -sysid "MEGA_CD" -iso-level 1 -o files.bin -pad _files

..\bin\asm68k.exe /p /q cdip\ip.asm, cdip\ip.bin,,cdip\ip.lst
..\bin\asm68k.exe /p /q cdsp\sp.asm, cdsp\sp.bin,,cdsp\sp.lst
..\bin\asm68k.exe /p /q main.asm, _out\disc.iso
del files.bin > nul

pause