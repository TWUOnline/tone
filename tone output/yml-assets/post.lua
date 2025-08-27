-- Post filters
-- Note: Post filters are called after Pandoc has done it's thing. This is useful for any improvements we want to make that extend beyond Quarto features. All calls are made bottom of the script.

------------------- HTML -------------------
-- Add Image Source below images

local function ImageSource_html_handler()
    local function parseText(text)
        local elements = {}
        local current_text = ""
        local in_italics = false
        
        if text:match("^%*.*%*$") then
            text = text:sub(2, -2)
            return {pandoc.Emph({pandoc.Str(text)})}
        end
        
        for part in text:gmatch("([^*]+)%*?") do
            if in_italics then
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
        
        if current_text ~= "" then
            table.insert(elements, pandoc.Str(current_text))
        end
        
        return elements
    end

    local function createSourceInfo(img)
        local function isNotEmpty(str)
            return str and str ~= ""
        end
    
        local source_content = {
            pandoc.Strong({pandoc.Emph({pandoc.Str("Source: ")})})
        }
        
        if isNotEmpty(img.attributes["source-link"]) then
            local link_text = isNotEmpty(img.attributes["source-text"]) and img.attributes["source-text"] or img.attributes["source-link"]
            local parsed_text = parseText(link_text)
            local source_link = pandoc.Link(
                parsed_text,
                img.attributes["source-link"],
                "",
                {target="_blank"}
            )
            table.insert(source_content, source_link)
        elseif isNotEmpty(img.attributes["source-text"]) then
            local parsed_text = parseText(img.attributes["source-text"])
            for _, element in ipairs(parsed_text) do
                table.insert(source_content, element)
            end
        end
    
        if isNotEmpty(img.attributes["source-author"]) then
            table.insert(source_content, pandoc.Str(" by "))
            if isNotEmpty(img.attributes["source-author-link"]) then
                local parsed_author = parseText(img.attributes["source-author"])
                local author_link = pandoc.Link(
                    parsed_author,
                    img.attributes["source-author-link"],
                    "",
                    {target="_blank"}
                )
                table.insert(source_content, author_link)
            else
                local parsed_author = parseText(img.attributes["source-author"])
                for _, element in ipairs(parsed_author) do
                    table.insert(source_content, element)
                end
            end
        end
    
        if isNotEmpty(img.attributes["source-copyright"]) then
            if #source_content > 1 then
                table.insert(source_content, pandoc.Str("."))
            end
            table.insert(source_content, pandoc.Space())
            table.insert(source_content, pandoc.Emph({pandoc.Str("Copyright:")}))
            table.insert(source_content, pandoc.Space())
            local parsed_copyright = parseText(img.attributes["source-copyright"])
            for _, element in ipairs(parsed_copyright) do
                table.insert(source_content, element)
            end
        end
    
        if isNotEmpty(img.attributes["source-license-text"]) then
            if #source_content > 1 then
                table.insert(source_content, pandoc.Str("."))
                table.insert(source_content, pandoc.Space())
                table.insert(source_content, pandoc.Emph({pandoc.Str("License Text:")}))
                table.insert(source_content, pandoc.Space())
            end
            
            if isNotEmpty(img.attributes["source-license-link"]) then
                local parsed_license = parseText(img.attributes["source-license-text"])
                local license_link = pandoc.Link(
                    parsed_license,
                    img.attributes["source-license-link"],
                    "",
                    {target="_blank"}
                )
                
                table.insert(source_content, license_link)
            else
                local parsed_license = parseText(img.attributes["source-license-text"])
                for _, element in ipairs(parsed_license) do
                    table.insert(source_content, element)
                end
            end
        end
    
        if #source_content > 1 then
            table.insert(source_content, pandoc.Str("."))
        end
    
        local result = {}
        table.insert(result, pandoc.Space())
        table.insert(result, pandoc.Span(source_content, {class="image-source"}))
        
        return result
    end
  
    local function handleImage(el)
        return el
    end

    local function handlePara(el)
        if el.parent and el.parent.attr and el.parent.attr.classes then
            for _, class in ipairs(el.parent.attr.classes) do
                if class == "figure" or class == "quarto-figure" then
                    return el
                end
            end
        end
        
        if #el.content == 1 then
            local img = nil
            
            if el.content[1].t == "Image" then
                img = el.content[1]
            elseif el.content[1].t == "Link" then
                for _, item in ipairs(el.content[1].content) do
                    if item.t == "Image" then
                        img = item
                        break
                    end
                end
            end
            
            if img and (img.attributes["source-text"] or img.attributes["source-link"] or 
               img.attributes["source-author"] or img.attributes["source-copyright"] or 
               img.attributes["source-license-text"]) then
                local source_inlines = createSourceInfo(img)
                local source_para = pandoc.Para(source_inlines)
                return {el, source_para}
            end
        end
        
        return el
    end

    local function handleDiv(el)
        if el.attr and el.attr.classes and 
           (el.attr.classes:includes("lightbox") or el.attr.classes:includes("quarto-float")) then
            
            local function findImageWithSource(content)
                for _, item in ipairs(content) do
                    if item.t == "Image" and 
                       (item.attributes["source-text"] or item.attributes["source-link"]) then
                        return item
                    elseif item.t == "Link" and item.content then
                        for _, subitem in ipairs(item.content) do
                            if subitem.t == "Image" and 
                               (subitem.attributes["source-text"] or subitem.attributes["source-link"]) then
                                return subitem
                            end
                        end
                    elseif item.content then
                        local found = findImageWithSource(item.content)
                        if found then return found end
                    end
                end
                return nil
            end
            
            local img = findImageWithSource(el.content)
            if img then
                local source_inlines = createSourceInfo(img)
                local source_para = pandoc.Para(source_inlines)
                return {el, source_para}
            end
        end
        
        return el
    end

    return {
        Image = handleImage,
        Para = handlePara,
        Div = handleDiv,
    }
end



local function RemoveFigcaption_dec_images_handler()
    -- Figure handler function
    local function handleFigure(el)
        -- Check if this is a quarto figure container
        if el.classes and (el.classes:includes('quarto-figure') or el.classes:includes('quarto-float')) then
            -- Check if figure has fig-id
            local has_fig_id = el.identifier and el.identifier:match("^fig%-")
            
            if not has_fig_id then
                -- Create new content without figcaption Plain block
                local new_content = {}
                for i, item in ipairs(el.content) do
                    -- Only exclude Plain blocks that contain figcaption
                    local include_item = true
                    if item.t == "Plain" then
                        for _, inline in ipairs(item.content) do
                            if inline.t == "RawInline" and inline.text:match("^<figcaption") then
                                include_item = false
                                break
                            end
                        end
                    end
                    
                    if include_item then
                        table.insert(new_content, item)
                    end
                end
                
                el.content = new_content
                return el
            end
        end
        
        return el
    end

    -- Return the transformation function
    return {
        Div = handleFigure
    }
end

local function restructure_image_source()
    local function handlePara(el)
        
        -- Check if this paragraph contains a span with class "image-source"
        local hasImageSourceSpan = false
        local spanContent = nil
        
        for _, item in ipairs(el.content) do
            if item.t == "Span" and item.attr and item.attr.classes and 
               (item.attr.classes:includes("image-source") or 
                item.attr.classes:find("image-source")) then
                hasImageSourceSpan = true
                spanContent = item.content
                break
            end
        end
        
        if hasImageSourceSpan and spanContent then
            -- Create new paragraph with raw HTML tags
            return pandoc.RawBlock('html', 
                '<p class="image-source">' .. 
                pandoc.write(pandoc.Pandoc({pandoc.Para(spanContent)}), 'html'):match('<p>(.*)</p>') ..
                '</p>'
            )
        end
        
        return el
    end
    
    return {
        Para = handlePara
    }
end
  


-- Makes accordions tab-able
local function Accordion_html_handler()
    local accordion_count = 0
    
    return {
        Div = function(el)
            if el.classes:includes("accordion") then
                accordion_count = accordion_count + 1
                local id = "accordion-" .. accordion_count
                local target = "." .. id .. "-contents"
                
                -- Get title from attributes, use default if nil or empty
                local title = el.attributes.title
                if not title or title:match("^%s*$") then
                title = "Click/Tap to expand."
                end
                -- Remove title from attributes
                el.attributes.title = nil
                
                -- Create a new div with the accordion structure
                local new_div = pandoc.Div({
                  pandoc.RawBlock('html', string.format([[
                    <div class="callout-header d-flex align-content-center" data-bs-toggle="collapse" data-bs-target="%s" aria-controls="%s" aria-expanded="false" aria-label="Toggle callout">
                        <div class="callout-icon-container">
                            <i class="callout-icon no-icon"></i>
                        </div>
                        <div class="callout-title-container flex-fill">
                            %s
                        </div>
                        <button class="callout-btn-toggle d-inline-block border-0 py-1 ps-1 pe-0 float-end"><i class="callout-toggle"></i></button>
                    </div>
                    <div id="%s" class="%s callout-collapse collapse">
                        <div class="callout-body-container callout-body">
                  ]], target, id, title, id, id .. "-contents")),
                  -- Insert original content here
                  table.unpack(el.content),
                  -- Close the divs
                  pandoc.RawBlock('html', [[
                        </div>
                    </div>
                  ]])
                })
                
                -- Add the outer classes
                new_div.classes = {"callout", "callout-style-simple", "accordion", "callout-note", "no-icon", "callout-titled"}
                
                return new_div
            end
            return el
        end
    }
  end
  

------------------- Docx -------------------
-- Utility function for HTML decoding
local function decode_html_entities(str)
  return str:gsub("&amp;", "&")
         :gsub("&lt;", "<")
         :gsub("&gt;", ">")
         :gsub("&quot;", '"')
         :gsub("&#39;", "'")
end

-- H5P handling function
local function h5p_docx_handler()
  local function process_h5p_iframe(el)
    if el.text:match('<iframe[^>]+src="[^"]+"[^>]*>') then
      local src = el.text:match('src="([^"]+)"')
      if src and src:match("h5p_embed") then
        src = decode_html_entities(src)
        return pandoc.Para(pandoc.Link(src, src))
      end
    end
    return el
  end

  return {
    RawBlock = process_h5p_iframe
  }
end

-- Header handling function
local function header_docx_handler()
  return {
    Header = function(el)
      el.identifier = ""
      return el
    end
  }
end

-- Remove figure numbering
local function remove_fig_numbering_docx_handler()
  -- Function to check if a paragraph contains figure numbering
  local function contains_figure_numbering(para)
      local has_figure = false
      for i, elem in ipairs(para.content) do
          if elem.t == "Str" and elem.text == "Figure" then
              -- Look ahead for number and colon
              local j = i + 1
              local found_number = false
              while j <= #para.content do
                  local next_elem = para.content[j]
                  if next_elem.t == "Str" then
                      if next_elem.text:match("^%d+$") then
                          found_number = true
                      elseif found_number and next_elem.text:match("^:") then
                          has_figure = true
                          break
                      end
                  end
                  j = j + 1
              end
          end
      end
      return has_figure
  end

  -- Function to rebuild paragraph without the figure number
  local function rebuild_paragraph_without_number(para)
      local new_content = {}
      local i = 1
      while i <= #para.content do
          local elem = para.content[i]
          
          if elem.t == "Str" and elem.text == "Figure" then
              -- Add "Figure"
              table.insert(new_content, elem)
              
              -- Skip until we find the colon
              while i < #para.content do
                  i = i + 1
                  elem = para.content[i]
                  if elem.t == "Str" and elem.text:match("^:") then
                      table.insert(new_content, elem)
                      break
                  end
              end
          else
              table.insert(new_content, elem)
          end
          i = i + 1
      end
      
      return pandoc.Para(new_content)
  end

  return {
      Para = function(para)
          if contains_figure_numbering(para) then
              return rebuild_paragraph_without_number(para)
          end
          return para
      end
  }
end

-- Remove default quarto handling of captions numbering
local function remove_default_captions_docx_handler()
    -- Function to check if content forms a figure caption
    local function is_figure_caption(content)
        -- Skip any initial RawInline elements
        local start_idx = 1
        while content[start_idx] and content[start_idx].t == "RawInline" do
            start_idx = start_idx + 1
        end

        -- Check for "Figure" pattern
        if content[start_idx] and content[start_idx].t == "Str" and
           (content[start_idx].text:match("^Figure") or
            content[start_idx].text:match("^Fig%.") or
            content[start_idx].text:match("^FIGURE")) then
            
            -- Look for number in next elements
            for i = start_idx + 1, start_idx + 2 do
                if content[i] and content[i].t == "Str" and content[i].text:match("%d") then
                    return true
                end
            end
        end
        return false
    end

    return {
        Figure = function(fig)
            if fig.content and #fig.content > 0 then
                local plain = fig.content[1]
                if plain and plain.content then
                    for _, elem in ipairs(plain.content) do
                        if elem.t == "Image" then
                            return pandoc.Para({elem})
                        end
                    end
                    return pandoc.Para(plain.content)
                end
            end
            return fig
        end,

        Para = function(para)
            if is_figure_caption(para.content) then
                return pandoc.Para({})
            end
            return para
        end
    }
end
-- Remove default quarto handling of images
local function left_align_images()
    -- Helper function to create OpenXML alignment
    local function create_left_align_xml()
        return pandoc.RawInline(
            'openxml',
            '<w:pPr>\n<w:jc w:val="left"/>\n</w:pPr>\n'
        )
    end

    -- Helper function to find and extract image from content
    local function extract_image(content)
        for _, block in ipairs(content) do
            if block.t == "Plain" or block.t == "Para" then
                for _, inline in ipairs(block.content) do
                    if inline.t == "Image" then
                        -- Create new image with left alignment
                        return pandoc.Para({
                            create_left_align_xml(),
                            pandoc.Image(
                                inline.caption,
                                inline.src,
                                inline.title,
                                pandoc.Attr(
                                    "",
                                    {"align-left"},
                                    {
                                        ["style"] = "text-align: left !important;",
                                        ["align"] = "left"
                                    }
                                )
                            )
                        })
                    end
                end
            end
        end
        return nil
    end

    return {
        Div = function(div)
            if div.attr and div.attr.identifier and div.attr.identifier:match("^fig%-") then
                -- Extract image and return it directly
                local extracted_image = extract_image(div.content)
                if extracted_image then
                    return extracted_image
                end
            end
            return div
        end
    }
end

-- Callouts handling function
local function callouts_docx_handler()
    local function format_time(time)
      if not time then
        return ""
      elseif time:match("%D") then
        return time
      else
        return time .. " mins"
      end
    end
  
    local function create_custom_div(type, content, icon, time, is_learning_activity, is_accordion, title)
        -- Create the opening line as separate parts
        local opening_parts = {}
        table.insert(opening_parts, pandoc.Str("<Begin "))
        table.insert(opening_parts, pandoc.Str(type))
        if icon then
          table.insert(opening_parts, pandoc.Str("-with-icon"))
        end
        table.insert(opening_parts, pandoc.Str(">"))
        
        local closing_line = {}
        table.insert(closing_line, pandoc.Str("<End "))
        table.insert(closing_line, pandoc.Str(type))
        if icon then
            table.insert(closing_line, pandoc.Str("-with-icon"))
        end
        table.insert(closing_line, pandoc.Str(">"))
        
        local result_content = {
          pandoc.Para(opening_parts),  -- Use the array of Str elements
        }
        
        if is_learning_activity then
          table.insert(result_content, 
            pandoc.Para({
              pandoc.Str("<meta>"),
              pandoc.Strong({pandoc.Str("Estimated Time")}),
              pandoc.Strong({pandoc.Str(": ")}),
              pandoc.Str(format_time(time)),
              pandoc.Str("</meta>")
            })
          )
        elseif is_accordion then
          table.insert(result_content, 
            pandoc.Para({
              pandoc.Str("<meta>"),
              pandoc.Strong({pandoc.Str("Title")}),
              pandoc.Strong({pandoc.Str(": ")}),
              pandoc.Str(title or ""),
              pandoc.Str("</meta>")
            })
          )
        end
        
        table.insert(result_content, pandoc.Div(content))
        table.insert(result_content, pandoc.Para(closing_line))
        
        local result = pandoc.Div(result_content)
        
        in_callout = false
        return result
    end
  
    local function process_div(div)
      if in_callout then
        return div
      end
      return div
    end
  
    local function process_callouts(div)
      if in_callout then
        return div
      end
  
      local callout_types = {
        ["learning-activity"] = {name = "learning-activity"},
        ["check"] = {name = "checking-your-learning"},
        ["note"] = {name = "note"},
        ["accordion"] = {name = "accordion"}
      }
  
      for class, info in pairs(callout_types) do
        if div.classes:includes(class) then
          return create_custom_div(
            info.name,
            div.content,
            div.attributes.icon,
            div.attributes.time,
            class == "learning-activity",
            class == "accordion",
            div.attributes.title
          )
        end
      end
  
      return div
    end
  
    return {
      Div = function(div)
        local result = process_callouts(div)
        return pandoc.walk_block(result, {Div = process_div})
      end
    }
end


-- style handling function
local function add_styles_docx_handler()
    local STYLES = {
        meta = {
            default = {
                size = 16,
                color = nil,
                bold = false
            },
            strong = {
                size = 16,
                color = nil,
                bold = true
            }
        },
        -- Figure references (ex "@fig-something")
        ref = {
            size = 24,
            color = "255e81",
            bold = false,
            italic = true
        },
        sections = {
            ["learning-activity"] = {
            color = "6ecfb1",
                size = 24,
                bold = true
            },
            ["checking-your-learning"] = {
                color = "f7a474",
                size = 24,
                bold = true
            },
            ["accordion"] = {
                color = "749fa3",
                size = 24,
                bold = true
            },
            ["note"] = {
                color = "577ecb",
                size = 24,
                bold = true
            },
            ["note-with-icon"] = {
                color = "577ecb",
                size = 24,
                bold = true
            },
            ["figure"] = {
                color = "7f1caa", 
                size = 24,
                bold = true
            },
            ["fig-image"] = {
                color = "f4a6d2", 
                size = 24,
                bold = true
            },
            ["dec-image"] = {
                color = "749fa3",
                size = 24,
                bold = true
            }
        }
    }

    local function process_refs(content)
        local has_ref = false
        local new_content = {}
        
        for _, inline in ipairs(content) do
            local text = pandoc.utils.stringify(inline)
            
            while text:find("<ref>.-</ref>") do
                has_ref = true
                local before_ref = text:match("^.-<ref>") and text:match("^(.-)<ref>") or ""
                local ref_content = text:match("<ref>(.-)</ref>")
                local after_ref = text:match("</ref>.*$") and text:match("</ref>(.*)$") or ""
                
                if before_ref ~= "" then
                    table.insert(new_content, pandoc.Str(before_ref))
                end
                
                if ref_content then
                    local style = STYLES.ref
                    local xml_open = string.format(
                        '<w:r><w:rPr><w:color w:val="%s"/><w:sz w:val="%d"/><w:szCs w:val="%d"/>%s%s</w:rPr><w:t>',
                        style.color,
                        style.size,
                        style.size,
                        style.bold and '<w:b/>' or '',
                        style.italic and '<w:i/>' or ''
                    )
                    table.insert(new_content, pandoc.RawInline('openxml', xml_open))
                    table.insert(new_content, pandoc.Str('@' .. ref_content))
                    table.insert(new_content, pandoc.RawInline('openxml', '</w:t></w:r>'))
                end
                
                text = after_ref
            end
            
            if text ~= "" and not text:find("<ref>.-</ref>") then
                table.insert(new_content, pandoc.Str(text))
            end
        end
        
        return has_ref, new_content
    end

    local in_meta_block = false
    local function style_line(elem)
        if elem.t == "BulletList" or elem.t == "OrderedList" then
    local new_items = {}
    for i, item in ipairs(elem.content) do
        if item.content then
            for j, block in ipairs(item.content) do
                if block.content then
                    local has_ref, new_content = process_refs(block.content)
                    if has_ref then
                        item.content[j] = pandoc.Para(new_content)
                    end
                end
            end
        end
        table.insert(new_items, item)
    end
    elem.content = new_items
    return elem
end

if elem.t == "Para" or elem.t == "Plain" then
    if elem.content then
        local has_ref, new_content = process_refs(elem.content)
        if has_ref then
            return pandoc.Para(new_content)
        end
    end
end

if elem.t == "Para" and elem.content then
    local has_meta = false
    local new_content = {}
    
    -- Helper function for XML escaping
    local function escape_xml(s)
        return s:gsub('&', '&amp;')
               :gsub('<', '&lt;')
               :gsub('>', '&gt;')
               :gsub('"', '&quot;')
               :gsub("'", '&apos;')
    end
    
    -- Generate OpenXML for text with specific style
    local function create_styled_text(text, style)
        return string.format(
            '<w:r><w:rPr>%s<w:sz w:val="%d"/><w:szCs w:val="%d"/>%s</w:rPr><w:t xml:space="preserve">%s</w:t></w:r>',
            style.color and string.format('<w:color w:val="%s"/>', style.color) or '',
            style.size,
            style.size,
            style.bold and '<w:b/>' or '',
            escape_xml(text)
        )
    end
    
    -- Process meta content
    local paragraphs = {}
    local current_inlines = {}
    
    for _, inline in ipairs(elem.content) do
        local text = pandoc.utils.stringify(inline)
        
        if text:match("<meta>") then
            has_meta = true
            in_meta_block = true
        elseif text:match("</meta>") then
            in_meta_block = false
            -- Flush any remaining content
            if #current_inlines > 0 then
                table.insert(paragraphs, pandoc.Para(current_inlines))
                current_inlines = {}
            end
        elseif in_meta_block then
            local style
            if inline.t == "Strong" then
                style = STYLES.meta.strong
            else
                style = STYLES.meta.default
            end
            
            if inline.t == "SoftBreak" or inline.t == "LineBreak" then
                -- Instead of creating a new paragraph, add a line break within the current paragraph
                if #current_inlines > 0 then
                    table.insert(current_inlines, pandoc.RawInline('openxml', '<w:r><w:br/></w:r>'))
                end
            elseif inline.t == "Link" then
                -- Handle links
                local link_text = pandoc.utils.stringify(inline.content)
                local link_url = inline.target
                local styled_content = pandoc.RawInline('openxml', create_styled_text(link_text, style))
                table.insert(current_inlines, 
                    pandoc.Link({styled_content}, link_url))
            else
                -- Handle regular text
                local content_text = pandoc.utils.stringify(inline)
                table.insert(current_inlines, 
                    pandoc.RawInline('openxml', 
                        create_styled_text(content_text, style, false)))
            end
        else
            table.insert(current_inlines, inline)
            if inline.t == "SoftBreak" or inline.t == "LineBreak" then
                table.insert(paragraphs, pandoc.Para(current_inlines))
                current_inlines = {}
            end
        end
    end

-- Add any remaining content
if #current_inlines > 0 then
    table.insert(paragraphs, pandoc.Para(current_inlines))
end
    
    if has_meta then
        return paragraphs
    end
end

local line = pandoc.utils.stringify(elem)

for section_name, style in pairs(STYLES.sections) do
    local begin_pattern = "<Begin " .. section_name .. ">"
    local end_pattern = "<End " .. section_name .. ">"
    
    if line == begin_pattern or line == end_pattern then
        local function escape_xml(s)
            return s:gsub('&', '&amp;')
                   :gsub('<', '&lt;')
                   :gsub('>', '&gt;')
                   :gsub('"', '&quot;')
                   :gsub("'", '&apos;')
        end
        local xml_open = string.format(
    '<w:r><w:rPr><w:color w:val="%s"/><w:sz w:val="%d"/><w:szCs w:val="%d"/>%s</w:rPr><w:t xml:space="preserve">%s</w:t></w:r>',
    style.color,
    style.size,
    style.size,
    style.bold and '<w:b/>' or '',
    escape_xml(line)
)

return pandoc.Para({
    pandoc.RawInline('openxml', xml_open)
})

                end
            end
            
            return elem
        end

        return {
            Para = style_line,
            Plain = style_line,
            BulletList = style_line,
            OrderedList = style_line
        }
    end


------------------- Calls -------------------

if quarto.doc.is_format("html") then
  return {
    ImageSource_html_handler(),
    restructure_image_source(),
    RemoveFigcaption_dec_images_handler(),
    Accordion_html_handler(),
  }
    end

if quarto.doc.is_format("docx") then
  return {
    h5p_docx_handler(),
    callouts_docx_handler(),
    header_docx_handler(),
    remove_default_captions_docx_handler(),
    left_align_images(),
    add_styles_docx_handler(),

  }
end 