# required bitmap display settings:
# unit width in pixels = 8
# unit height in pixels = 8
# display width in pixels = 256
# display height in pixels = 256
# base address for display = ($gp)


.data
	.align 2 # ensure word-aligned bitmap array
	bitmap: .space 262144 # allocate 256x256 bytes (pixels) to draw
	black: .word 0x00000000 # black color
	colors: .word 0x00FF0000, 0x00FFA500, 0x00FFFF00, 0x0000FF00, 0x000000FF, 0x004B0082, 0x00800080, 0x00FF1493, 0x00000000, 0x00FFFFFF

.text	

	# start pixel middle
	# 32x32 grid
		li $a0, 16 # x=16
		li $a1, 16 # y=16
		li $s6, 0 # current color index
		lw $a3, colors($s6) # color[0]=red
		li $s4, 50000 # ************ADJUST THIS FOR PIXEL MOVEMENT SPEED IF YOUR CPU IS FAST
		jal drawPixel
	
	mainLoop:
		# get user input
		lw $s0, 0xffff0004
		beq $s0, 0x71, end # if user presses q -> end
		
		# convert input to LRUD 0123
		beq $s0, 0x61, pressLeft   # a
		beq $s0, 0x64, pressRight # d
		beq $s0, 0x77, pressUp # w 
		beq $s0, 0x73, pressDown # s
		beq $s0, 0x65, nextColor # e
		
		li $s0, 0
		sw $s0, 0xffff0004

		updatePixel:
		jal delay

		j mainLoop
	
	end:
	li $v0, 10
	syscall
	
		pressLeft:
			jal movePixelLeft
			j updatePixel
		pressRight:
			jal movePixelRight
			j updatePixel
		pressUp:
			jal movePixelUp
			j updatePixel
		pressDown:
			jal movePixelDown
			j updatePixel
		nextColor:
			jal changeColor
			li $t0, 0
			sw $t0, 0xffff0004
			j updatePixel
	
	# def delay()
	delay:
		addi $sp, $sp, -8
		sw $ra, 0($sp)
		sw $t0, 4($sp)
		
		move $t0, $s4 # delay amount 
		delayLoop:
			beqz $t0, endDelayLoop
			addi $t0, $t0, -1 # decrement 
			j delayLoop
		endDelayLoop:
		lw $t0, 4($sp)
		lw $ra, 0($sp)
		addi $sp, $sp, 8
		jr $ra
	
	#def changeColor()->None
	# increment $s6 color index, set $a3 to next color in arr
	changeColor:
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		addi $s6, $s6, 1
		li $t0, 10
		div $s6, $t0 # color index % 10
		mfhi $t0
		mul $t0, $t0, 4 # take color index, map to color[] mem location
		lw $a3, colors($t0) # set new color at this index
		
		jal drawPixel # redraw pixel here
		
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		
	# pixel always starts at (16,16)
	# def movePixelLeft()->None:
	movePixelLeft:
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		# first check if has space to move left i.e. if $a0 < 0: don't move
		ble $a0, 0, outboundLeft
		
		# draw pixel @ (x-1, y)
		addi $a0, $a0, -1
		jal drawPixel
		
		outboundLeft:
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	# def movePixelRight()->None:
	movePixelRight:
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		# first check if has space to move right i.e. if $a0 >= 31: don't move
		bge $a0, 31, outboundRight
		
		# draw pixel @ (x+1, y)
		addi $a0, $a0, 1
		jal drawPixel
		
		outboundRight:
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	# def movePixelDown()->None:
	movePixelDown:
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		# first check if has space to move down i.e. if $a0 > 31: don't move
		bge $a1, 31, outboundDown
		
		# draw pixel @ (x, y+1)
		addi $a1, $a1, 1
		jal drawPixel
		
		outboundDown:
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	# def movePixelUp()->None:
	movePixelUp:
		addi $sp, $sp, -4
		sw $ra, 0($sp)
		
		# first check if has space to move up i.e. if $a1 <= 0: don't move
		blez $a1, outboundUp
		
		# draw pixel @ (x, y-1)
		addi $a1, $a1, -1
		jal drawPixel
		
		outboundUp:
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
		

	# def drawPixel(int x, int y, color)->None
	# x: a0, y: a1, color: a3
	drawPixel:
		addi $sp, $sp, -4 # first save ra on stack
		sw $ra, 0($sp)
		
		
		
		jal calcPixelCoord
		
		sw $a3, 0($v0) # draw pixel at address
		
		# Clean stack
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	# Assume 32x32 ints:: a0: int x, a1: int y -> v0: int positionToDrawPixel
	calcPixelCoord:
		addi $sp, $sp, -4 # first save ra on stack
		sw $ra, 0($sp)
	
		li $t1, 4 # pixel size
		la $t0, 0($gp) # base address for bitmap
	
		# memmoryAddr = baseAddr + x + y
		# x = (4*col)
		# y = (256*4*row of 8x8 blocks)
	
		# first calculate x:  -> store inside $t2
		mul $t2, $t1, $a0 # 4*x
	
		# calculate y: -> store inside $t3 
		li $t3, 128 # Offset for one 8x8 block down from the top
    		mul $t3, $t3, $a1 # Offset for the desired row
	
		# sum baseAddr to x+y
		add $t3, $t3, $t2 # x + y
		add $v0, $t0, $t3 # baseAdrr + (x+y)
		
		# sum baseAddr to x+y
   		add $v0, $t0, $t3 # baseAddr + (x+y)
	
		# Address to draw pixel stored in $v0
		
		# Clean stack
		lw $ra, 0($sp)
		addi $sp, $sp, 4
		jr $ra
	
	
