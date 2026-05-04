package main

import "core:fmt"
import "core:mem"
import "core:strings"
import "base:runtime"
import sdl "vendor:sdl3"


window : ^sdl.Window = nil
renderer : ^sdl.Renderer = nil
render_target : ^sdl.Texture = nil
window_width : i32 = 640
window_height : i32 = 480


InputModes :: enum
{
	Pen,
	Mouse
}
drawing : bool = false
drawing_mode : InputModes = .Pen
pressure : f32 = 0.0
previous_touch_x : f32 = -1.0
previous_touch_y : f32 = -1.0
current_hover_x : f32 = 0.0
current_hover_y : f32 = 0.0



DisplayDebugInfo :: proc(renderer : ^sdl.Renderer)
{
	sdl.SetRenderScale(renderer, 2.0, 2.0)
	defer sdl.SetRenderScale(renderer, 1.0, 1.0)
	sdl.SetRenderDrawColor(renderer, 0, 0, 0, 255)

	debug_text_x : f32 = 10.0
	debug_text_y : f32 = 10.0

	debug_values : [5]cstring = {
		fmt.ctprintf("%s : %f", "current_hover_x", current_hover_x),
		fmt.ctprintf("%s : %f", "current_hover_y", current_hover_y),
		fmt.ctprintf("%s : %v", "drawing", drawing),
		fmt.ctprintf("%s : %s", "drawing_mode", drawing_mode),
		fmt.ctprintf("%s : %f", "pressure", pressure)
	}

	// Loop through the values and display them appropriately
	for s in debug_values
	{

		if !sdl.RenderDebugText(renderer, debug_text_x, debug_text_y, s)
		{
			fmt.printf("Failed to render debug text %s", sdl.GetError())
		}

		debug_text_y += 20
	}

}



DrawPenOutline :: proc(renderer : ^sdl.Renderer)
{
	points: [dynamic]sdl.FPoint
	defer delete(points)

	x : f32 = 10.0
	y: f32 = 0
	err := f32(0)

	for x >= y {
	  append(&points, sdl.FPoint{current_hover_x + x, current_hover_y + y})
	  append(&points, sdl.FPoint{current_hover_x + y, current_hover_y + x})
	  append(&points, sdl.FPoint{current_hover_x - y, current_hover_y + x})
	  append(&points, sdl.FPoint{current_hover_x - x, current_hover_y + y})
	  append(&points, sdl.FPoint{current_hover_x - x, current_hover_y - y})
	  append(&points, sdl.FPoint{current_hover_x - y, current_hover_y - x})
	  append(&points, sdl.FPoint{current_hover_x + y, current_hover_y - x})
	  append(&points, sdl.FPoint{current_hover_x + x, current_hover_y - y})

	  y += 1
	  err += 1 + 2 * y
	  if 2 * (err - x) + 1 > 0 {
	      x -= 1
	      err += 1 - 2 * x
	  }
	}

	sdl.RenderPoints(renderer, raw_data(points), i32(len(points)))
}



// Intiailises the app
AppInit :: proc "c" (appstate : ^rawptr, argc : i32, argv : [^]cstring) -> sdl.AppResult
{
	context = runtime.default_context()

	fmt.println("Beep boop starting up!")

	sdl.SetHint(sdl.HINT_PEN_MOUSE_EVENTS, "0")
	sdl.SetHint("SDL_PEN_MOUSE_EVENTS", "0")


	// Initialise sdl
	if !sdl.Init({ .VIDEO})
	{
		fmt.printf("Failed to init %s", sdl.GetError())
		return sdl.AppResult.FAILURE
	}


	// Hide the cursor
	ok := sdl.HideCursor()
	if !ok
	{
		fmt.printf("Failed to hide cursor", sdl.GetError())
		return sdl.AppResult.FAILURE
	}


	// Create the renderer
	if !sdl.CreateWindowAndRenderer("Drawing pad", window_width, window_height, {.RESIZABLE}, &window, &renderer)
	{
		fmt.printf("Failed to create window and renderer %s", sdl.GetError())
		return sdl.AppResult.FAILURE
	}


	// Create the texture
	sdl.GetRenderOutputSize(renderer, &window_width, &window_height)
	render_target = sdl.CreateTexture(renderer, sdl.PixelFormat.RGBA8888, sdl.TextureAccess.TARGET, window_width, window_height)
	if (render_target == nil)
	{
		fmt.printf("Failed to setup texture %s", sdl.GetError())
		return sdl.AppResult.FAILURE
	}


	// Setup the rest of the renderer e.g. background colour
	sdl.SetRenderTarget(renderer, render_target)
	sdl.SetRenderDrawColor(renderer, 100, 100, 100, sdl.ALPHA_OPAQUE)
	sdl.RenderClear(renderer)

	sdl.SetRenderTarget(renderer, nil)
	sdl.SetRenderDrawBlendMode(renderer, sdl.BLENDMODE_BLEND)

	return sdl.AppResult.CONTINUE
}



// Handles individual events
AppEvent :: proc "c" (appstate : rawptr, event : ^sdl.Event) -> sdl.AppResult
{
	context = runtime.default_context()

	#partial switch event.type
	{
		case .QUIT:
			return sdl.AppResult.FAILURE

		case .PEN_DOWN:
			drawing = true
			drawing_mode = .Pen

		case .PEN_UP:
			drawing = false
			drawing_mode = .Pen

		case .MOUSE_BUTTON_DOWN:
			drawing = true
			drawing_mode = .Mouse

		case .MOUSE_BUTTON_UP:
			drawing = false
			drawing_mode = .Mouse

		// Drawing logic
		case .PEN_MOTION, .MOUSE_MOTION:

			current_hover_x = event.pmotion.x
			current_hover_y = event.pmotion.y

			if drawing == true && drawing_mode == .Mouse // Mouse drawing - always full opacity as no pressure
			{
				if previous_touch_x >= 0.0 // only draw if moving
				{
					sdl.SetRenderTarget(renderer, render_target)
					sdl.SetRenderDrawColorFloat(renderer, 0, 0, 0, 255)
					sdl.RenderLine(renderer, previous_touch_x, previous_touch_y, current_hover_x, current_hover_y)
				}
				previous_touch_x = event.pmotion.x
				previous_touch_y = event.pmotion.y
			}
			else if drawing == true && drawing_mode == .Pen && pressure > 0.0 // Pen drawing - pressure sensitive, more pressure = more opaque
			{
				if previous_touch_x >= 0.0
				{
					sdl.SetRenderTarget(renderer, render_target)
					sdl.SetRenderDrawColorFloat(renderer, 0, 0, 0, pressure)
					sdl.RenderLine(renderer, previous_touch_x, previous_touch_y, current_hover_x, current_hover_y)
				}
				previous_touch_x = event.pmotion.x
				previous_touch_y = event.pmotion.y
			}
			else if pressure <= 0.0 && drawing == false
			{
	            previous_touch_x = -1.0
	            previous_touch_y = -1.0
        	}


		// Accessing the pen pressure
		case .PEN_AXIS:
			if event.paxis.axis == .PRESSURE
			{
				pressure = event.paxis.value
			}
	}

	return sdl.AppResult.CONTINUE
}



// Update and render logic, runs repeatedly once per frame
AppIterate :: proc "c" (appstate : rawptr) -> sdl.AppResult
{
	context = runtime.default_context()

	// Make sure to draw to window not render target
	sdl.SetRenderTarget(renderer, nil)
	sdl.SetRenderDrawColor(renderer, 0, 0, 0, sdl.ALPHA_OPAQUE)
	sdl.RenderClear(renderer)

	// Render the texture
	sdl.RenderTexture(renderer, render_target, nil, nil)

	// Render the other stuff
	DisplayDebugInfo(renderer)
	DrawPenOutline(renderer)

	// Present everything
	sdl.RenderPresent(renderer)

	return sdl.AppResult.CONTINUE
}



// Clean up
AppQuit :: proc "c" (appstate: rawptr, result: sdl.AppResult)
{
	context = runtime.default_context()
	sdl.DestroyTexture(render_target)
	sdl.DestroyRenderer(renderer)
	sdl.DestroyWindow(window)
	fmt.println("Quiting")
}



main :: proc()
{
	argv : cstring = ""
	sdl.EnterAppMainCallbacks(
		0,
		&argv,
		appinit = AppInit,
		appiter = AppIterate,
		appevent = AppEvent,
		appquit = AppQuit
	)
}
