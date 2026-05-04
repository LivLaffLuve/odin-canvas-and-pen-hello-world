package main

import "core:fmt"
import sdl "vendor:sdl3"


// Global params
window_width :: 720
window_height :: 260
render_flag : bool = false
x_position, y_position : f32
curr_x, curr_y, last_x, last_y : i32 = 0, 0, 0, 0
pixels : [window_height][window_width]bool
drawing : bool = false


// Bresenham line drawing - fills pixels between two points
draw_line :: proc(x0, y0, x1, y1 : ^i32) 
{
    dx := abs(x1^ - x0^)
    dy := -abs(y1^ - y0^)
    sx := x0^ < x1^ ? 1 : -1
    sy := y0^ < y1^ ? 1 : -1
    err := dx + dy
    
    for {
        if x0^ >= 0 && x0^ < window_width && y0^ >= 0 && y0^ < window_height {
            pixels[y0^][x0^] = true
        }
        if x0^ == x1^ && y0^ == y1^ do break
        
        e2 := 2 * err
        if e2 >= dy {
            err += dy
            x0^ += i32(sx)
        }
        if e2 <= dx {
            err += dx
            y0^ += i32(sy)
        }
    }
}



render_canvas :: proc(renderer : ^sdl.Renderer)
{
	sdl.SetRenderDrawColor(renderer, 255, 0, 0, sdl.ALPHA_OPAQUE)
	
	for y in 0..<window_height
	{
		for x in 0..<window_width
		{
			if pixels[y][x] == true
			{
				a : sdl.FRect = {f32(x), f32(y), 2, 2}
				sdl.RenderFillRect(renderer, &a)
			}
		}
	}

}


main :: proc() {
	
	// Create the renderer
	ok := sdl.Init({.VIDEO}); assert(ok)
	window : ^sdl.Window
	renderer : ^sdl.Renderer
	sdl.CreateWindowAndRenderer("Renderer", window_width, window_height, nil, &window, &renderer)
	defer sdl.DestroyRenderer(renderer)
	defer sdl.DestroyWindow(window)
	defer sdl.Quit()

	// Start the event loop
	main_loop: for
	{
		event: sdl.Event

		for sdl.PollEvent(&event)
		{
			#partial switch event.type
			{
				// Handling quiting
				case .QUIT:
					break main_loop
				
				case .KEY_DOWN:
					if event.key.scancode == .ESCAPE do break main_loop
				
				// If left mouse button held down
				case .MOUSE_BUTTON_DOWN:
					if (event.button.button == 1 && event.button.down == true)
					{
						curr_x = i32(event.motion.x)
        				curr_y = i32(event.motion.y)
						last_x = i32(event.button.x)
						last_y = i32(event.button.y)
						fmt.printfln("Initial x and y click (%i) (%i)", last_x, last_y)
						
						// Bound checking
						if (last_x >= 0 && last_x < window_width && last_y >= 0 && last_y < window_height)
						{
							pixels[last_y][last_x] = true
						}
					}

					drawing = true

				// If mouse button released
				case .MOUSE_BUTTON_UP:
					fmt.printfln("Mouse button released")
					drawing = false

				// If mouse is moving
				case .MOUSE_MOTION:
					if drawing == true
					{	
						// Get the motion data
						curr_x := i32(event.motion.x)
        				curr_y := i32(event.motion.y)
						fmt.printfln("Event motion x, y (%i) (%i)", event.motion.x, event.motion.y)

						// Bound checking
						if curr_x >= 0 && curr_x < window_width && curr_y >= 0 && curr_y < window_height 
						{
							// Do the interpolation
							draw_line(&last_x, &last_y, &curr_x, &curr_y)
							
							// Update the last position data to the current x ready for new points
							last_x = curr_x
							last_y = curr_y
						}
					}
                    
			}
		}

		sdl.SetRenderDrawColor(renderer, 0xFF, 0xFF, 0xFF, sdl.ALPHA_OPAQUE)
		sdl.RenderClear(renderer)

		render_canvas(renderer)
		
		sdl.RenderPresent(renderer)
		sdl.Delay(16)	
	}

}
