-- Pre filters
-- Note: Pre filters are called before Pandoc does it's thing. This is useful for any improvements we want to make that take advantage of Quarto features. All calls are made bottom of the script.

------------------- HTML -------------------
-- Callout handler function
local function callouts_html_handler()
  local function create_callout(div_type, content, title, appearance, icon)
    return quarto.Callout({
      type = "note",
      content = content,
      title = title,
      appearance = appearance or "default",
      icon = icon or false
    })
  end

  local function process_callouts(div)
    local callout_types = {
      ["learning-activity"] = {
        title = function(attrs) 
          if attrs.time then
            -- Check if time contains any non-digit characters
            if attrs.time:match("%D") then
              -- If it contains text, use as is
              return "Estimated Time: " .. attrs.time
            else
              -- If it's just a number, append "mins"
              return "Estimated Time: " .. attrs.time .. " mins"
            end
          end
          return " "
        end,
        appearance = "default"
      },
      ["check"] = {
        title = function() return "Checking Your Learning" end,
        appearance = "default"
      },
      ["note"] = {
        title = function() return nil end,
        appearance = "simple",
        icon = function(attrs) return attrs.icon or false end
      }
    }

    for class, config in pairs(callout_types) do
      if div.classes:includes(class) then
        return create_callout(
          class,
          div.content,
          config.title(div.attributes),
          div.attributes.appearance or config.appearance,
          config.icon and config.icon(div.attributes)
        )
      end
    end

    return div
  end

  return {
    Div = process_callouts
  }
end

-- Prote comment handler function
local function protes_html_handler()
  local function process_prote(div)
    -- If div has class "prote", return empty list to remove it
    if div.classes:includes("prote") then
      return {}
    end
    -- Otherwise return div unchanged
    return div
  end

  return {
    Div = process_prote
  }
end

-- Responsive tables handler function
local function responsive_tables_html_handler()
  return {
    Table = function(el)
      local table_container = pandoc.Div(el, pandoc.Attr("", {"table-container"}))
      local parent_container = pandoc.Div(table_container, pandoc.Attr("", {"parent-table-container"}))
      return parent_container
    end
  }
end



------------------- PDF -------------------
-- Callout handler function
local function callouts_pdf_handler()
  local function create_callout(content, title, appearance, icon, collapse)
    return quarto.Callout({
      type = "note",
      content = content,
      title = title,
      appearance = appearance,
      icon = icon,
      collapse = collapse
    })
  end

  local function process_callouts(div)
    local callout_types = {
      ["learning-activity"] = {
        title = function(attrs) 
          return attrs.title and ("Learning Activity: " .. attrs.title) or "Learning Activity"
        end,
        appearance = "default",
        icon = false
      },
      ["check"] = {
        title = function() return "Checking Your Learning" end,
        appearance = "default",
        icon = false
      },
      ["note"] = {
        title = function() return nil end,
        appearance = "simple",
        icon = function(attrs) return attrs.icon or false end
      },
      ["accordion"] = {
        title = function(attrs) return attrs.title or "Open to learn more." end,
        appearance = "simple",
        icon = false,
        collapse = function(attrs) return attrs.collapse or true end
      }
    }

    for class, config in pairs(callout_types) do
      if div.classes:includes(class) then
        return create_callout(
          div.content,
          config.title(div.attributes),
          div.attributes.appearance or config.appearance,
          config.icon and config.icon(div.attributes) or config.icon,
          config.collapse and config.collapse(div.attributes)
        )
      end
    end

    return div
  end

  return {
    Div = process_callouts
  }
end

-- Prote comment handler function
local function protes_pdf_handler()
  local function process_prote(div)
    -- If div has class "prote", return empty list to remove it
    if div.classes:includes("prote") then
      return {}
    end
    -- Otherwise return div unchanged
    return div
  end

  return {
    Div = process_prote
  }
end

------------------- Docx -------------------
-- Prote handler function
local function protes_docx_handler()
  local in_callout = false

  local function create_callout(type, content, title, appearance, icon)
    return quarto.Callout({
      type = type,
      content = content,
      title = title,
      appearance = appearance or "default",
      icon = icon
    })
  end

  local function process_div(div)
    if in_callout then
      return div
    end
    return div
  end

  local function process_prote(div)
    if in_callout then
      return div
    end

    if div.classes:includes("prote") then
      in_callout = true
      local result = create_callout(
        "important",
        pandoc.walk_block(pandoc.Div(div.content), {Div = process_div}),
        "Note from Production",
        div.attributes.appearance or "simple",
        true
      )
      in_callout = false
      return result
    end

    return div
  end

  return {
      Div = process_prote
    }
  end

local function figimage_docx_handler()
  local function parseText(text)
    if not text then return {pandoc.Str("")} end
    
    local elements = {}
    local current_text = ""
    local in_italics = false
    
    -- Check if entire text is wrapped in asterisks
    if text:match("^%*.*%*$") then
        text = text:sub(2, -2)  -- Remove outer asterisks
        return {pandoc.Emph({pandoc.Str(text)})}
    end
    
    -- Handle partial italics
    for part in text:gmatch("([^*]+)%*?") do
        if in_italics then
            -- Add emphasized text
            if current_text ~= "" then
                table.insert(elements, pandoc.Str(current_text))
                current_text = ""
            end
            table.insert(elements, pandoc.Emph({pandoc.Str(part)}))
        else
            current_text = current_text .. part
        end
        in_italics = not in_italics
    end
    
    -- Add any remaining text
    if current_text ~= "" then
        table.insert(elements, pandoc.Str(current_text))
    end
    
    return elements
end
  local function get_image_metadata(element)
    local metadata = {}
    if element.t == "Image" and element.attr then
        -- Get existing attributes
        if element.attr.attributes then
            for k, v in pairs(element.attr.attributes) do
                metadata[k] = v
            end
        end
        -- Check for lightbox class
        if element.attr.classes then
            metadata["lightbox"] = "no"  -- default value
            for _, class in ipairs(element.attr.classes) do
                if class == "lightbox" then
                    metadata["lightbox"] = "yes"
                    break
                end
            end
        else
            metadata["lightbox"] = "no"
        end
    end
    return metadata
end
  -- metadata display names mapping
  local display_names = {
    ["fig-id"] = "Figure ID",
    ["fig-caption"] = "Caption",
    ["fig-alt"] = "Alt Text",
    ["lightbox"] = "Has Lightbox",
    ["source-text"] = "Source Text",
    ["source-link"] = "Source URL",
    ["source-author"] = "Author",
    ["source-author-link"] = "Author URL",
    ["source-copyright"] = "Copyright",
    ["source-license-text"] = "License Text",
    ["source-license-link"] = "License URL",
}
  local function create_metadata_block(metadata)
    local ordered_keys = {
      "fig-id",
      "fig-caption",
      "fig-alt",
      "lightbox",
      "source-text",
      "source-link",
      "source-author",
      "source-author-link",
      "source-copyright",
      "source-license-text",
      "source-license-link",

  }
    
  local inlines = {}
  table.insert(inlines, pandoc.Str("<meta>"))
  
  for i, key in ipairs(ordered_keys) do
      local display_name = display_names[key] or key
      table.insert(inlines, pandoc.Strong({pandoc.Str(display_name .. ": ")}))
      
      if key == "source-link" or key == "source-author-link" or key == "source-license-link" then
          local url = metadata[key] or ""
          if url ~= "" then
              table.insert(inlines, pandoc.Link({pandoc.Str(url)}, url))
          else
              table.insert(inlines, pandoc.Str(""))
          end
      else
          local value = metadata[key] or ""
          -- Check if this is an attribute that should support italics
          if key == "source-text" or key == "source-author" or 
             key == "source-copyright" or key == "source-license-text" then
              local parsed_elements = parseText(value)
              for _, element in ipairs(parsed_elements) do
                  table.insert(inlines, element)
              end
          else
              table.insert(inlines, pandoc.Str(value))
          end
      end
      
      if i < #ordered_keys then
          table.insert(inlines, pandoc.LineBreak())
      end
  end
  
  table.insert(inlines, pandoc.Str("</meta>"))
  return pandoc.Para(inlines)
end
  
  -- Rest of the code remains the same
  local function add_markers(element, metadata)
    local metadata_block = create_metadata_block(metadata)
    
    return pandoc.Div({
      pandoc.Para({pandoc.Str("<Begin fig-image>")}),
      metadata_block,
      pandoc.Para({}),
      element,
      pandoc.Para({}),
      pandoc.Para({pandoc.Str("<End fig-image>")})
    })
  end

  local function process_figure(fig)
    if not (fig.attr and fig.attr.identifier and fig.attr.identifier:match("^fig%-")) then
        return fig
    end

    local metadata = {}
    
    if fig.attr then
        local attr_str = tostring(fig.attr)
        local full_id = attr_str:match('^%("([^"]+)"')
        if full_id then
            -- If you'd rather not include "fig-" at the beginning of the fig id then use the below code.
            --local id = full_id:gsub("^fig%-", "")
            local id = "#" ..full_id
            metadata["fig-id"] = id
        end
end

    if fig.caption and fig.caption.long then
      local caption_parts = {}
      for _, elem in ipairs(fig.caption.long[1].content) do
          if elem.text then
              table.insert(caption_parts, elem.text)
          elseif elem.t == "Space" then
              table.insert(caption_parts, " ")
          end
      end
      metadata["fig-caption"] = table.concat(caption_parts)
    end

    local function find_image(content)
        if content.t == "Image" then
            return content
        end
        if content.content then
            for _, elem in ipairs(content.content) do
                local img = find_image(elem)
                if img then return img end
            end
        end
        return nil
    end

    local image = find_image(fig)
    if image then
        local image_metadata = get_image_metadata(image)
        for k, v in pairs(image_metadata) do
            metadata[k] = v
        end
    end
    
    return add_markers(fig, metadata)
  end
  local function process_para(para)
    if para.content then
        for _, elem in ipairs(para.content) do
            if elem.t == "Image" and elem.attr and elem.attr.identifier and elem.attr.identifier:match("^fig%-") then
                -- Only process if it has a #fig- identifier
                local metadata = get_image_metadata(elem)
                metadata["fig-id"] = elem.attr.identifier:gsub("^fig%-", "")
                return add_markers(para, metadata)
            end
        end
    end
    return para
end

return {
    Figure = process_figure,
    Para = process_para
}
end

local function decimage_docx_handler()
  local function parseText(text)
    if not text then return {pandoc.Str("")} end
    
    local elements = {}
    local current_text = ""
    local in_italics = false
    
    -- Check if entire text is wrapped in asterisks
    if text:match("^%*.*%*$") then
        text = text:sub(2, -2)  -- Remove outer asterisks
        return {pandoc.Emph({pandoc.Str(text)})}
    end
    
    -- Handle partial italics
    for part in text:gmatch("([^*]+)%*?") do
        if in_italics then
            -- Add emphasized text
            if current_text ~= "" then
                table.insert(elements, pandoc.Str(current_text))
                current_text = ""
            end
            table.insert(elements, pandoc.Emph({pandoc.Str(part)}))
        else
            current_text = current_text .. part
        end
        in_italics = not in_italics
    end
    
    -- Add any remaining text
    if current_text ~= "" then
        table.insert(elements, pandoc.Str(current_text))
    end
    
    return elements
end
  local function get_image_metadata(element)
    local metadata = {}
    if element.t == "Image" and element.attr and element.attr.attributes then
        for k, v in pairs(element.attr.attributes) do
            metadata[k] = v
        end
        
        -- If there's no fig-alt but there is a fig-caption, use fig-caption as fig-alt
        if not metadata["fig-alt"] and metadata["fig-caption"] then
            metadata["fig-alt"] = metadata["fig-caption"]
        end
        -- Check for lightbox class
        if element.attr.classes then
          metadata["lightbox"] = "no"  -- default value
          for _, class in ipairs(element.attr.classes) do
              if class == "lightbox" then
                  metadata["lightbox"] = "yes"
                  break
              end
          end
      else
          metadata["lightbox"] = "no"
      end
    end
    return metadata
end
  -- metadata display names mapping
  local display_names = {
    ["fig-alt"] = "Alt Text",
    ["lightbox"] = "Has Lightbox",
    ["source-text"] = "Source Text",
    ["source-link"] = "Source URL",
    ["source-author"] = "Author",
    ["source-author-link"] = "Author URL",
    ["source-copyright"] = "Copyright",
    ["source-license-text"] = "License Text",
    ["source-license-link"] = "License URL",
  }
  local function find_image(content)
    if content.t == "Image" then
        return content
    end
    if content.content then
        for _, elem in ipairs(content.content) do
            local img = find_image(elem)
            if img then return img end
        end
    end
    return nil
end
  local function create_metadata_block(metadata)
    local ordered_keys = {
        "fig-alt",
        "lightbox",
        "source-text",
        "source-link",
        "source-author",
        "source-author-link",
        "source-copyright",
        "source-license-text",
        "source-license-link",
    }
    
    local inlines = {}
    table.insert(inlines, pandoc.Str("<meta>"))
    
    for i, key in ipairs(ordered_keys) do
        local display_name = display_names[key] or key
        table.insert(inlines, pandoc.Strong({pandoc.Str(display_name .. ": ")}))
        
        if key == "source-link" or key == "source-author-link" or key == "source-license-link" then
            local url = metadata[key] or ""
            if url ~= "" then
                table.insert(inlines, pandoc.Link({pandoc.Str(url)}, url))
            else
                table.insert(inlines, pandoc.Str(""))
            end
        else
            local value = metadata[key] or ""
            -- Check if this is an attribute that should support italics
            if key == "source-text" or key == "source-author" or 
               key == "source-copyright" or key == "source-license-text" then
                local parsed_elements = parseText(value)
                for _, element in ipairs(parsed_elements) do
                    table.insert(inlines, element)
                end
            else
                table.insert(inlines, pandoc.Str(value))
            end
        end
        
        if i < #ordered_keys then
            table.insert(inlines, pandoc.LineBreak())
        end
    end
    
    table.insert(inlines, pandoc.Str("</meta>"))
    return pandoc.Para(inlines)
end

  local function add_markers(element, metadata)
    local metadata_block = create_metadata_block(metadata)
    
    return pandoc.Div({
      pandoc.Para({pandoc.Str("<Begin dec-image>")}),
      metadata_block,
      pandoc.Para({}),
      element,
      pandoc.Para({}),
      pandoc.Para({pandoc.Str("<End dec-image>")})
    })
  end

  local function process_para(para)
    if para.content then
        for _, elem in ipairs(para.content) do
            if elem.t == "Image" then
                -- Process if it either has no identifier or the identifier doesn't start with fig-
                if not (elem.attr and elem.attr.identifier and elem.attr.identifier:match("^fig%-")) then
                    local metadata = get_image_metadata(elem)
                    return add_markers(para, metadata)
                end
            end
        end
    end
    return para
end
local function process_figure(fig)
  -- Only process if the figure does NOT have a fig- identifier
  if not (fig.attr and fig.attr.identifier and fig.attr.identifier:match("^fig%-")) then
      local metadata = {}
      local image = find_image(fig)
      if image then
          metadata = get_image_metadata(image)
      end
      
      -- If there's a caption and no fig-alt, use the caption as fig-alt
      if fig.caption and fig.caption.long and not metadata["fig-alt"] then
          local caption_parts = {}
          for _, elem in ipairs(fig.caption.long[1].content) do
              if elem.text then
                  table.insert(caption_parts, elem.text)
              elseif elem.t == "Space" then
                  table.insert(caption_parts, " ")
              end
          end
          metadata["fig-alt"] = table.concat(caption_parts)
      end
      
      return add_markers(fig, metadata)
  end
  return fig
end

return {
  Para = process_para,
  Figure = process_figure,
}

end

local function figure_block_handler()
  -- Debug function remains the same

  local function create_metadata_block(metadata)
    local inlines = {}
    table.insert(inlines, pandoc.Str("<meta>"))

    -- Add identifier (should always be present)
    table.insert(inlines, pandoc.Strong({pandoc.Str("Figure ID: ")}))
    table.insert(inlines, pandoc.Str(metadata.identifier or ""))
    table.insert(inlines, pandoc.LineBreak())

    -- Add caption (with empty string if not present)
    table.insert(inlines, pandoc.Strong({pandoc.Str("Caption: ")}))
    table.insert(inlines, pandoc.Str(metadata.caption or ""))
    table.insert(inlines, pandoc.LineBreak())

    -- Add layout (with empty string if not present)
    table.insert(inlines, pandoc.Strong({pandoc.Str("Columns: ")}))
    table.insert(inlines, pandoc.Str(metadata.layout or ""))
    
    table.insert(inlines, pandoc.Str("</meta>"))
    return pandoc.Para(inlines)
end

  local function process_div(div)
    -- Only process if it's a figure div (starts with "fig-")
    if div.attr and div.attr.identifier and div.attr.identifier:match("^fig%-") then

        -- Extract metadata
        local metadata = {
            identifier = "#" .. div.attr.identifier,
            layout = div.attr.attributes and div.attr.attributes["layout-ncol"],
        }

        -- Find caption (usually the last Para in content) and remove it
        if div.content and #div.content > 0 then
            local last_block = div.content[#div.content]
            if last_block.t == "Para" then
                metadata.caption = table.concat(
                    last_block.content:map(function(elem) 
                        return elem.text or (elem.t == "Space" and " ") or ""
                    end)
                )
                -- Remove the last block (caption) from content
                table.remove(div.content)
            end
        end

        -- Create new blocks array
        local new_blocks = {
            pandoc.Para({pandoc.Str("<Begin figure>")}),
            create_metadata_block(metadata)
        }

        -- Add all remaining content blocks
        for i = 1, #div.content do
            table.insert(new_blocks, div.content[i])
        end

        -- Add the end marker
        table.insert(new_blocks, pandoc.Para({pandoc.Str("<End figure>")}))

        return pandoc.Div(new_blocks)
    end
    return div
end

  return {
      Div = process_div
  }
end

local function figure_reference_pre_handler()
  return {
      Cite = function(el)
          if el.citations and #el.citations > 0 then
              local citation = el.citations[1]
              if citation.id then
                  if citation.id:match("^fig%-") then
                      -- Create new element as plain text
                      local new_text = "<ref>" .. citation.id .. "</ref>"
                      return pandoc.Str(new_text)
                  end
              end
          end
          
          return el
      end,
      
      Str = function(el)
          if el.text:match("^@fig%-%S+") then
  
              local id = el.text:gsub("^@", "")
              local new_text = "<ref>" .. id .. "</ref>"
              return pandoc.Str(new_text)
          end
          return el
      end
  }
end

------------------- Calls -------------------

if quarto.doc.is_format("html") then
  return {
    callouts_html_handler(),
    protes_html_handler(),
    responsive_tables_html_handler(),
  }
end

if quarto.doc.is_format("pdf") then
  return {
    callouts_pdf_handler(),
    protes_pdf_handler(),
  }
end

if quarto.doc.is_format("docx") then
  return {
    protes_docx_handler(),
    figimage_docx_handler(),
    decimage_docx_handler(),
    figure_block_handler(),
    figure_reference_pre_handler(),
  }
end