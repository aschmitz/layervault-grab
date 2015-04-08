dofile("urlcode.lua")
dofile("table_show.lua")

local url_count = 0
local tries = 0
local item_type = os.getenv('item_type')
local item_value = os.getenv('item_value')

local site = {}
local author = {}
local filename = {}

local downloaded = {}
local addedtolist = {}

local status_code = nil

intable = function(kind, str)
  for k, v in pairs(kind) do
    local k1 = string.gsub(k, "%-", "%%-")
    if string.match(str, "/"..k1) then
      return true
    end
  end
  return false
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]
  
  if downloaded[url] == true or addedtolist[url] == true then
    return false
  end
  
  if item_type == "project" and (downloaded[url] ~= true or addedtolist[url] ~= true) then
    if (string.match(url, "/"..item_value.."[0-9][0-9]") and not string.match(url, "/"..item_value.."[0-9][0-9][0-9]")) or html == 0 or (intable(site, url) == true and intable(author, url) == true) or string.match(url, "%.css") or string.match(url, "%.js") then
      addedtolist[url] = true
      return true
    else
      return false
    end
  elseif item_type == "file" and (downloaded[url] ~= true or addedtolist[url] ~= true) then
    if (string.match(url, "/"..item_value.."[0-9][0-9]") and not string.match(url, "/"..item_value.."[0-9][0-9][0-9]")) or html == 0 or (intable(site, url) == true and intable(author, url) == true and intable(filename, url) == true) or string.match(url, "%.css") or string.match(url, "%.js") then
      addedtolist[url] = true
      return true
    else
      return false
    end
  end
end


wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil
  
  local function check(url)
    if (downloaded[url] ~= true and addedtolist[url] ~= true) and not (string.match(url, "%%7B") or string.match(url, "%%7D") or string.match(url, "{") or string.match(url, "}")) then
      table.insert(urls, { url=url })
      addedtolist[url] = true
    end
  end
  
  if status_code ~= 404 then
    if item_type == "project" then
      if string.match(url, "layervault%.com/api/v2/projects/") and string.match(url, "/"..item_value.."[0-9][0-9]") and not string.match(url, "/"..item_value.."[0-9][0-9][0-9]") then
        html = read_file(file)
        for newurl in string.gmatch(html, '"(https?://[^"]+)"') do
          local author1 = string.match(newurl, "https?://[^/]+/([^/]+)/")
          local site1 = string.match(newurl, "https?://[^/]+/[^/]+/(.+)")
          site[site1] = true
          author[author1] = true
          check("https://layervault.com/"..author1.."/"..site1.."/project-assets")
          check("https://layervault.com/"..author1.."/"..site1.."/discussions")
          check("https://layervault.com/"..author1.."/"..site1.."/presentations")
          check(newurl)
        end
      end
      if intable(site, url) == true and intable(author, url) == true then
        html = read_file(file)
        for newurl in string.gmatch(html, '"(https?://[^"]+)"') do
          if (intable(site, newurl) == true and intable(author, newurl) == true) or string.match(newurl, "imgix%.net") then
            check(newurl)
          end
        end
        for newurl in string.gmatch(html, '"(/[^"]+)"') do
          if intable(site, newurl) == true and intable(author, newurl) == true then
            check("https://layervault.com"..newurl)
          end
        end
      end
    elseif item_type == "file" then
      if string.match(url, "layervault%.com/api/v2/files/") and string.match(url, "/"..item_value.."[0-9][0-9]") and not string.match(url, "/"..item_value.."[0-9][0-9][0-9]") then
        html = read_file(file)
        for newurl in string.gmatch(html, '"(https?://[^"]+)"') do
          local author1 = string.match(newurl, "https?://[^/]+/([^/]+)/[^/]+/.+")
          local site1 = string.match(newurl, "https?://[^/]+/[^/]+/([^/]+)/.+")
          local filename1 = string.match(newurl, "https?://[^/]+/[^/]+/([^/]+)/(.+)")
          site[site1] = true
          author[author1] = true
          filename[filename1] = true
          check(newurl)
        end
      end
      if string.match(url, "/revisions/[0-9]+/") then
        local revnum = string.match(url, "/revisions/([0-9]+)/")
        while revnum ~= 0 do
          check(string.gsub(url, "revisions/[0-9]+/", "revisions/"..revnum.."/"))
          revnum = revnum - 1
        end
      end
      if intable(site, url) == true and intable(author, url) == true and intable(filename, url) == true then
        html = read_file(file)
        for cluster in string.gmatch(html, '"revisions_cluster":"([0-9]+)"') do
          check("https://layervault.com/api/v2/revision_clusters/"..cluster)
        end
        for newurl in string.gmatch(html, '"(https?://[^"]+)"') do
          if string.match(newurl, "imgix%.net") or (intable(site, newurl) == true and intable(author, newurl) == true and intable(filename, newurl) == true) or string.match(newurl, "layervault%.com/api/v2/previews/[0-9]+") or string.match(newurl, "layervault%.com/api/v2/revisions/[0-9]+") or string.match(newurl, "layervault%.com/files/download_node/") then
            check(newurl)
          end
        end
        for revision_number in string.gmatch(html, '"revision_number":([0-9]+)') do
          if not string.match(url, "/revisions/[0-9]+") then
            check(url.."/revisions/"..revision_number.."/previews/1")
            check(url.."/revisions/"..revision_number.."/previews")
            check(url.."/revisions/"..revision_number)
          end
        end
      end
      if string.match(url, "layervault%.com/api/v2/revisions/[0-9]+") or string.match(url, "layervault%.com/api/v2/revision_clusters/[0-9]+") or string.match(url, "layervault%.com/api/v2/previews/[0-9]+") then
        html = read_file(file)
        for newurl in string.gmatch(html, '"(https?://[^"]+)"') do
          check(newurl)
        end
      end
    end
  end

  return urls
end
  

wget.callbacks.httploop_result = function(url, err, http_stat)
  -- NEW for 2014: Slightly more verbose messages because people keep
  -- complaining that it's not moving or not working
  status_code = http_stat["statcode"]
  
  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. ".  \n")
  io.stdout:flush()

  if (status_code >= 200 and status_code <= 399) then
    if string.match(url.url, "https://") then
      local newurl = string.gsub(url.url, "https://", "http://")
      downloaded[newurl] = true
    else
      downloaded[url.url] = true
    end
  end
  
  if status_code >= 500 or
    (status_code >= 400 and status_code ~= 404 and status_code ~= 403) then

    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 1")

    tries = tries + 1

    if tries >= 2 and not string.match(url["url"], "layervault%.com") or string.match(url["url"], "layervau%.lt") then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.EXIT
    elseif tries >= 2 and status_code == 500 then
      io.stdout:write("\nMoving on...\n")
      io.stdout:flush()
    elseif tries >= 15 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  elseif status_code == 0 then

    if string.match(url["url"], "https?://layervault%-preview%.imgix%.net") then
      return wget.actions.EXIT
    end

    io.stdout:write("\nServer returned "..http_stat.statcode..". Sleeping.\n")
    io.stdout:flush()

    os.execute("sleep 10")
    
    tries = tries + 1

    if tries >= 2 and not string.match(url["url"], "layervault%.com") or string.match(url["url"], "layervau%.lt") then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.EXIT
    elseif tries >= 10 then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      return wget.actions.ABORT
    else
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  -- We're okay; sleep a bit (if we have to) and continue
  -- local sleep_time = 0.5 * (math.random(75, 100) / 100.0)
  local sleep_time = 0

  --  if string.match(url["host"], "cdn") or string.match(url["host"], "media") then
  --    -- We should be able to go fast on images since that's what a web browser does
  --    sleep_time = 0
  --  end

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end
