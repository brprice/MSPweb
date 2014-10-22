module OneOhOne where

import System.Locale
import Data.Time -- (UTCTime(..), showGregorian)
import Data.Time.Format 

import System.FilePath 

import Data.List
import Data.Ord
import Control.Arrow

-- HTML utils 

nl2br :: String -> String
nl2br [] = []
nl2br ('\n':xs) = "<br/>\n" ++ nl2br xs
nl2br (x:xs) = x:(nl2br xs)

createLink :: String -> String -> String
createLink [] name = name
createLink url name = "<a href='" ++ url ++ "'>" ++ name ++ "</a>"

bracket :: String -> String
bracket str = if null str then "" else " (" ++ str ++ ")"



wordwrap maxlen div = (wrap_ 0) . words where
	wrap_ _ [] = ""
	wrap_ pos (w:ws)
		-- at line start: put down the word no matter what
		| pos == 0 = w ++ wrap_ (pos + lw) ws
		| pos + lw + 1 > maxlen = div ++ wrap_ 0 (w:ws)
		| otherwise = " " ++ w ++ wrap_ (pos + lw + 1) ws
		where lw = length w


-- Generate web pages, calendars and a RSS feed for MSP 101 from data in 
-- a text file

-- Extra material, such as slides, source code, ...
type Material = (FilePath, String) -- ^ path and description

data Talk = Talk {
                   date :: UTCTime,
                   speaker :: String,
                   institute :: String,
                   speakerurl :: String,
                   insturl :: String,
                   title :: String,
                   abstract :: String,
                   location :: String,
                   material :: [Material]
                 }

          | SpecialEvent {
                           date :: UTCTime,
                           title :: String,
                           url :: String,
                           location :: String,
                           locationurl :: String,
                           description :: String
                         }
  deriving (Show, Read, Eq)



generateRSS :: [(Int,Talk)]
            -> FilePath -- ^ Output path
            -> IO ()
generateRSS ts out = do
  let content = concatMap processEntry ts
      header = unlines ["<?xml version='1.0' encoding='ISO-8859-1'?>",
                        "<rss version='2.0' xmlns:atom='http://www.w3.org/2005/Atom'>",
                        " <channel>",
                        "  <title>MSP101</title>",
                        "  <link>http://msp.cis.strath.ac.uk/msp101.html</link>",
                        "  <description>MSP101 is an ongoing series of informal talks given on Wednesday mornings by visiting academics or members of the MSP group.</description>",
                        "  <language>en-gb</language>"]
      footer = unlines [" </channel>", "</rss>"]
  writeFile out (header ++ content ++ footer)
    where processEntry (i,(Talk date speaker inst speakerurl insturl title abstract location material))
            = let rsstitle = (showGregorian $ utctDay date) ++ ": " ++ speaker ++ bracket inst 
                  abstr = if (null abstract) then "" else "<p><b>Abstract</b><br/><br/>" ++  (nl2br abstract) ++ "</p>"
                  desc = unlines ["<h2>" ++ (createLink speakerurl speaker) ++ (bracket (createLink insturl inst)) ++ "</h2>",
                                  "<h2>" ++ title ++ "</h2>",
                                  abstr, 
                                  "<b>" ++ (show date) ++ "<br/>" ++ location ++ "</b><br/>"]
              in
               unlines ["  <item>", 
                        "   <title>" ++ rsstitle ++ "</title>",
                        "   <description><![CDATA[" ++ desc ++ "]]></description>",
                        "   <guid isPermaLink='true'>http://msp.cis.strath.ac.uk/msp101.html#" ++ (show i) ++ "</guid>",
                        "  </item>"]
          processEntry (i,(SpecialEvent date title url location locationurl description)) 
            = let rsstitle = (showGregorian $ utctDay date) ++ ": " ++ title 
                  abstr = if (null description) then "" else "<p>" ++  (nl2br description) ++ "</p>"
                  desc = unlines ["<h2>" ++ (createLink url title) ++ (bracket location) ++ "</h2>",
                                  "<h2>" ++ title ++ "</h2>",
                                  abstr, 
                                  "<b>" ++ (show date) ++ "<br/>" ++ (createLink locationurl location) ++ "</b><br/>"]
              in
               unlines ["  <item>", 
                        "   <title>" ++ rsstitle ++ "</title>",
                        "   <description><![CDATA[" ++ desc ++ "]]></description>",
                        "   <guid isPermaLink='true'>http://msp.cis.strath.ac.uk/msp101.html#" ++ (show i) ++ "</guid>",
                        "  </item>"]

            
generateICS :: [(Int,Talk)]
            -> FilePath -- ^ Output path
            -> IO ()
generateICS ts out = do
  now <- getZonedTime
  let content = concatMap (processEntry now) ts
      header = unlines ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//MSP//MSP101 v1.0//EN",
                        "X-WR-CALNAME: MSP101",
                        "X-WR-CALDESC: MSP101 seminar series"]
      footer = unlines ["END:VCALENDAR"]
  writeFile out (header ++ content ++ footer)
    where processEntry now (i,(Talk date speaker inst speakerurl insturl title abstract location material)) 
            = let desc = escape $ unlines ["Speaker: " ++ speaker ++ " " ++ (bracket inst),
                                  "Title: " ++ title ++ "\n",
                                  abstract]
                  end = addUTCTime (60*60::NominalDiffTime) date
              in 
                  unlines ["BEGIN:VEVENT",
                           "DTSTAMP;TZID=Europe/London:" ++ (formatTime defaultTimeLocale "%Y%m%dT%H%M%S" now),
                           "DTSTART;TZID=Europe/London:" ++ (formatTime defaultTimeLocale "%Y%m%dT%H%M%S" date), 
                           "DTEND;TZID=Europe/London:" ++ (formatTime defaultTimeLocale "%Y%m%dT%H%M%S" $ end),
                           "LOCATION:" ++ location,
                           wordwrap 73 "\n  " $ "SUMMARY:" ++ title,
                           wordwrap 73 "\n  " $ "DESCRIPTION:" ++ desc,
                           "UID:" ++ (show i),
                           "END:VEVENT"]
                    where escape :: String -> String
                          escape [] = []
                          escape ('\\':xs) = "\\\\" ++ (escape xs)
                          escape ('\n':xs) = "\\n" ++ (escape xs)
                          escape (';':' ':xs) = "\\; " ++ (escape xs)
                          escape (',':' ':xs) = "\\, " ++ (escape xs)
                          escape (x:xs) = x:(escape xs)
          processEntry now (i,(SpecialEvent date title url location locationurl description))
            = let desc = escape $ description
                  end = addUTCTime (60*60::NominalDiffTime) date
              in 
                  unlines ["BEGIN:VEVENT",
                           "DTSTAMP;TZID=Europe/London:" ++ (formatTime defaultTimeLocale "%Y%m%dT%H%M%S" now),
                           "DTSTART;TZID=Europe/London:" ++ (formatTime defaultTimeLocale "%Y%m%dT%H%M%S" date), 
                           "DTEND;TZID=Europe/London:" ++ (formatTime defaultTimeLocale "%Y%m%dT%H%M%S" $ end),
                           "LOCATION:" ++ location,
                           wordwrap 73 "\n  " $ "SUMMARY: Event: " ++ title,
                           wordwrap 73 "\n  " $ "DESCRIPTION:" ++ desc,
                           "UID:" ++ (show i),
                           "END:VEVENT"]
                    where escape :: String -> String
                          escape [] = []
                          escape ('\\':xs) = "\\\\" ++ (escape xs)
                          escape ('\n':xs) = "\\n" ++ (escape xs)
                          escape (';':' ':xs) = "\\; " ++ (escape xs)
                          escape (',':' ':xs) = "\\, " ++ (escape xs)
                          escape (x:xs) = x:(escape xs)          

generateHTML :: [(Int,Talk)]
            -> FilePath -- ^ Output path
            -> IO ()
generateHTML ts out = do
  now <- fmap zonedTimeToUTC getZonedTime --getCurrentTime
  let (previousTalks, upcomingTalks) = sortBy (flip $ comparing $ date . snd) *** sortBy (comparing $ date . snd) $ partition (\(i,x) -> date x < now) ts
      upcoming = if null upcomingTalks then "" else unlines ["<h2>Upcoming talks</h2>",
                                                             "<dl>", concatMap processEntry upcomingTalks, "</dl>"]

      previous = if null previousTalks then "" else unlines ["<h2>List of previous talks</h2>",
                                                             "<dl>", concatMap processEntry previousTalks, "</dl>"]

      
      header = unlines ["### default.html(section.msp101=current,headtags=<link rel='alternate' type='application/rss+xml' title='MSP101 seminars RSS feed' href='/msp101.rss'/>)",
                        "<!-- DO NOT EDIT THIS FILE DIRECTLY -- EDIT OneOhOneTalks.hs AND RUN Generate101.hs INSTEAD -->",
                        "<h2>MSP101</h2>",
                        "<p>MSP101 is an ongoing series of informal talks by visiting academics or members of the MSP group. The talks are usually Wednesday mornings 11am in room LT1310 in Livingstone Tower. They are usually announced on the <a href='https://lists.cis.strath.ac.uk/mailman/listinfo/msp-interest'>msp-interest</a> mailing-list. The list of talks is also available as a <a type='application/rss+xml' href='/msp101.rss'><img src='/images/feed-icon-14x14.png'>RSS feed</a> and as a <a href='msp101.ics'>calendar file</a>.</p>"]
  writeFile out (header ++ upcoming ++ previous)
    where processEntry (i,(Talk date speaker inst speakerurl insturl title abstract location material)) 
            = let time = if utctDayTime date == timeOfDayToTime (TimeOfDay 11 0 0) then (showGregorian $ utctDay date) else (formatTime defaultTimeLocale "%Y-%m-%d, %H:%M" date)
                  place = if location == "LT1310" then "" else (bracket location)
                  person = if null inst then (createLink speakerurl speaker)
                                        else (createLink speakerurl speaker) ++ ", " ++ (createLink insturl inst)
                  dt = time ++ place ++ ": " ++ title ++ (bracket person)
              in 
                 unlines ["  <dt id='" ++ (show i) ++ "'>" ++ dt ++ "</dt>",
                          "    <dd>" ++ (nl2br abstract) ++ "</dd>"]
          processEntry (i,(SpecialEvent date title url location locationurl description))
            = let time = formatTime defaultTimeLocale "%Y-%m-%d" date
                  dt = time ++ ": " ++ (createLink url title)
                                    ++ (bracket (createLink locationurl location))
              in 
                 unlines ["  <dt id='" ++ (show i) ++ "'>" ++ dt ++ "</dt>",
                          "    <dd>" ++ (nl2br description) ++ "</dd>"]