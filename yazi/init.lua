-- Bridge Yazi's hovered-file event to the DMS native QML preview pane.
-- The destination is supplied by FilesTerminal as a per-screen environment
-- variable, so parallel screens never overwrite each other's selection.
local preview_file = os.getenv("DMS_YAZI_PREVIEW_FILE")

if preview_file and preview_file ~= "" then
	local publish_hover = function()
		local hovered = cx.active.current.hovered
		local path = hovered and tostring(hovered.url) or ""
		ya.async(function()
			fs.write(Url(preview_file), path)
		end)
	end

	ps.sub("hover", publish_hover)
	ps.sub("cd", publish_hover)
end
