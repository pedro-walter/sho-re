ROM := Super Hang-On (World) (En,Ja) (Rev A).md
COVS := $(wildcard out/cov_*.txt)

# annotated disassembly (generated, not to be committed: contains the game's code)
disasm: disasm/sho.asm
disasm/sho.asm: tools/disasm.py tools/m68k.py disasm/annot/*.txt $(COVS)
	python3 -I tools/disasm.py "$(ROM)" $@ $(foreach c,$(COVS),--cov $(c))

# decoder self-check against MAME's unidasm
check-m68k:
	flatpak run --filesystem=$(PWD) --command=unidasm org.mamedev.MAME "$(ROM)" -arch m68000 -basepc 0 > out/unidasm.txt
	python3 -I tools/m68k_check.py "$(ROM)"
