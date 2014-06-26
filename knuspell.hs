module Main where


import qualified Data.Map as M
import System.Environment (getArgs)
import Data.List (sortBy)
import Control.Monad.State
--import Data.List.Ordered as O

data Trie = Node (M.Map Char Trie) deriving Show

main :: IO()
main = do
  args <- getArgs
  case args of
    ("hello": _) -> hello
    ["lineRev"] -> lineRev
    ("trieTest" : _) -> trie -- Just reads the contents of given file and converts it to a trie.
    ("minEdit" : _) -> minedit
    ("minEdits": _) -> minedits
    ("findBest": _) -> findbest
    ("cmdArgs" : _) -> cmdArgs
    ("corrText":_) -> correctText
    _ -> error "Sorry, I do not understand."

hello :: IO()
hello = do
  args <- fmap tail getArgs
  putStrLn $ "Hello " ++ unwords args ++ "."

lineRev :: IO()
lineRev = interact $ unlines . map (unwords . reverse . words) . lines

trie :: IO()
trie = do
  args <- getArgs
  file <- readFile (args!!1)
  putStrLn $ "Trie " ++ (args!!1) ++ "."
  putStrLn $ show {-$ M.size-} $ getMap $ makeTrie $ lines file
      where getMap (Node m) = m

minedit :: IO()
minedit = do
  args <- getArgs
  file <- readFile (args!!1)
  let rad = read (args !! 3) :: Int
      word = args !! 2
  putStrLn $ show $ findNeighbourhood rad word (makeTrie $ lines file)

minedits :: IO()
minedits = do
  args <- getArgs
  dict <- readFile (args !! 1)
  text <- readFile (args !! 2)
  putStrLn $ show $ map ((flip (findNeighbourhood 4)) (makeTrie $ lines dict)) (lines text) 

findbest :: IO()
findbest = do
  args <- getArgs
  dict <- readFile (args !! 1)
  let s = args !! 2
  putStrLn $ show $ findBest 10 s (makeTrie $ lines dict)

correctText :: IO()            
correctText = do
  args <- getArgs
  dict <- readFile (args !! 1)
  text <- readFile (args !! 2)
  putStrLn "You want me to correct the following text:"
  putStrLn text
  let rad = read (args !! 3) :: Int
      tree = makeTrie $ lines dict
  correctWords (words text) rad tree 

               
correctWords :: [String] -> Int -> Trie -> IO()
correctWords w0 r0 t0 = do
  case w0 of
    [] -> return ()
    (w1:w1s) -> correctWord w1 r0 t0 >> correctWords w1s r0 t0

correctWord :: String -> Int ->  Trie -> IO()
correctWord s0 r0 t0 = do
  messCorrPoss r0 s0 l0
    where l0 = findNeighbourhood r0 s0 t0

messCorrPoss :: Int -> String -> M.Map Int [String] -> IO()
messCorrPoss r0 s0 m0 =
  case M.size m0 of
    0 -> putStrLn $ "The word '" ++ s0 ++ "' you typed is most likely incorrect or not known to me. If it is incorrect there are >"++(show r0) ++ " mistakes in it." ++ "\n" -- first case --- no correction possible since out of threshold
    _ -> if M.member 0 m0
                 then return ()
                 else putStrLn $ "My suggestions are: " ++ unwords (M.foldr' (++) [] m0) ++ "\n"

  
cmdArgs :: IO()
cmdArgs = do
  args <- getArgs
  putStr $ show args

addToTrie :: String -> Trie -> Trie
addToTrie ""      (Node m) = Node (M.insert endChar (Node M.empty) m)

addToTrie (c : s) (Node m) = t'
  where
    t' = if M.member c m
         then Node (M.adjust (const (addToTrie s (m M.! c))) c m) 
         else Node (M.insert c (addToTrie s (Node M.empty)) m)
      
makeTrie :: [String] -> Trie
makeTrie ss = foldr addToTrie (Node M.empty) ss

trieToMap :: Trie -> M.Map Char Trie
trieToMap (Node m) = m

getTrie :: String -> Trie -> Trie
getTrie [] t = t
getTrie (s : ss) (Node m) = m M.! s 

update :: Char -> (Int,[(Char,Int)]) -> (Int,[(Char,Int)])
update c0 = update' 0 0
    where
      -- first is heuristic min edt dist (h)
      -- first two ints store the values needed for the sub and ins case in the next iteration
      update' :: Int -> Int -> (Int,[(Char,Int)]) -> (Int,[(Char,Int)]) 
      update' _ _ (_,(('#', i1) : ci2)) = (min i2 (fst ici0),('#', i2) : snd ici0) 
          where i2 = i1 + delcost c0
                ici0 = update' i1 i2 (i2,ci2) -- rest of the 'list'
      update' j0 j1 (h1,((c1,i1) : ci2)) = (min h2 (fst ici0),(c1,i2) : snd ici0)
          where i2 = minimum [ i1 + delcost c0, j0 + subcost c0 c1, j1 + inscost c1 ]   -- newly defined distance
                ici0 = update' i1 i2 (h2,ci2)
                h2 = min h1 i2
      update' _ _ (h1,[]) = (h1,[])       

minEditDist :: [(Char, Int)] -> Int
minEditDist [] = 9999
minEditDist x  = snd $ last x

insertBagBy :: (a -> a -> Ordering) -> a -> [a] -> [a]
insertBagBy cmp = loop
  where
    loop x [] = [x]
    loop x (y:ys)
      = case cmp x y of
         GT -> y:loop x ys
         _  -> x:y:ys

stringToCI :: String -> [(Char, Int)]
stringToCI s = (zip s [0..length s])

findBest :: Int -> String -> Trie -> [(Int, String)]
findBest i s t = [(minEditDist ci, map fst ci) | ci <- result]
    where
      
      result = evalState (findBest' i s) [([], t)] -- TODO: Something meaningful?!
      findBest' :: Int -> String -> State [([(Char, Int)], Trie)] [[(Char, Int)]]
      findBest' i s = do
                     st <- get
                     let
                         he        = searchFirst st
                         (hci, ht) = he
                         newElems  = map (\(c, t) -> (snd $ update c (minEditDist hci, hci), t))  $ M.toList $ trieToMap ht 
                         st'       = foldr (insertBagBy customOrder) st newElems
                     put st'
                     let
                         thresInd  = (min i (length st)) - 1
                         threshold = minEditDist $ fst $ (st !! thresInd)
                     put $ takeWhile (\x ->  (minEditDist $ fst x) < threshold) st'
                     if isComplete st'
                     then return (take i (map fst st'))
                     else findBest' i s
          where
            customOrder :: ([(Char, Int)], Trie) -> ([(Char, Int)], Trie) -> Ordering
            customOrder x y = compare (minEditDist $ fst x) (minEditDist $ fst y)

            -- finds the first element in the state, which is not fully expanded, and its index
            searchFirst ((cis, Node m) : ss) =
                if M.null m
                then searchFirst ss 
                else (cis, Node m)

            isComplete :: [([(Char, Int)], Trie)] -> Bool
            isComplete cit = and $ map (M.null . trieToMap . snd) cit
                 

-- operations to do to get from string in list to s0
-- first is radius
findNeighbourhood :: Int -> String -> Trie -> M.Map Int [String]
findNeighbourhood r0 s0 t0 = findNeighbourhood' r0 "" t0 (zip ('#':s0) [0..length s0]) 
  where
    -- first  : radius,
    -- second : current string,
    -- third  : length of current string,
    -- forth  : assoc list with substrings (chars) and min edt dists 
    findNeighbourhood' :: Int -> String -> Trie -> [(Char,Int)] -> M.Map Int [String]
    findNeighbourhood' r1 s1 (Node m0) ci0 = M.foldr' (M.unionWith (++)) M.empty (M.mapWithKey go m0)
      where
        go :: Char -> Trie -> M.Map Int [String] -- recursion function
        go '_' _ = if d0 > r1 then
                     M.empty -- return nothing (matching is out of threshold r1)
                   else
                     M.singleton (snd (last ci0)) [s1] -- return current string with minimum edit distance ('_' is endChar)
          where d0 = snd (last ci0) -- current minimum edit distance
        go c0 t1 = if h0>r1 then
                     M.empty
                   else
                      findNeighbourhood' r1 (s1++[c0]) t1 ci1
          where (h0,ci1) = update c0 (0,ci0) -- updated assoc list
    
endChar :: Char
endChar = '_'

startChar :: Char
startChar = '#'

delcost :: Char -> Int
delcost _ = 1

subcost :: Char -> Char -> Int
subcost c1 c2 = if c1 == c2 then 0 else 1

inscost :: Char -> Int
inscost _ = 1


-- diff :: Eq a => [a] -> [a] -> (Int, [Edit a])
-- diff s t = (cost, reverse edits) -- edits are build back to front... so they need to be reversed
--     where
--       n            = length t
--       m            = length s
--       inscost      = 1                              -- cost for insertion
--       delcost      = 1                              --          deletion
--       subcost :: Eq a => a -> a -> Int              --          substitution (depending on the two letters)
--       subcost x y  = if x == y then 0 else n + m    -- if they differ choose a number larger then maximum poscible
      
--       nm = (n + 1) * (m + 1) -- just an abbreviation for the next two definitions

--       -- equals [0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3, 0, 1, 2, 3] for n = 3, m = 4
--       listn = take nm $ cycle $ take (n+1) [0 ..]
--       -- equals [0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4] for n = 3, m = 4
--       listm = take nm $ concat $ map (\x -> take (n+1) (repeat x)) [0 ..]
--       listnm = zip listn listm

--       index k l = l * (n + 1) + k

--       -- The following function memoizes the outcomes of distance. For this it maps the distance onto 
--       -- the previously defined list of all pairs and picks the right value.
--       memodistance = \k l -> (list !! (index k l))
-- 	  where 
--             list = map (\(a, b) -> distance a b) listnm
--             -- distance :: Int -> Int -> (Int, [Edit a])
--             -- Interestingly the program does not compile then provided the type above, cince the function
--             -- makes use of the parameters s and t. Is there a way to explicitly state the type description
--             -- which depends on the type of the function, whose where clause the function is in?

--             -- On to this function: It implements the min-edit-distance function/matrix pretty straightforward as
--             -- described in the paper/textbook. The difference is, that this vercion appends the used edit in front
--             -- of an accumulating list of edits.
--             distance 0 0 = (0, [])
--             distance i 0 = (c + inscost, Insertion (t !! (i-1)) : ed)
--                 where (c, ed ) = memodistance (i-1) 0
--             distance 0 j = (c + delcost, Deletion (s !! (j-1)) : ed)
--                 where (c, ed ) = memodistance 0 (j-1)
--             distance i j = minimumBy (\x y -> compare (fst x) (fst y))
--                            [ (c1 + inscost, (Insertion (t !! (i-1)) : ed1))
--                            , (c2 + subcost (s !! (j-1)) (t !! (i-1)), (Substitution (s !! (j-1))) : ed2)
--                            , (c3 + delcost, (Deletion (s !! (j-1))) : ed3)
--                            ]
--                 where 
--                   (c1, ed1) = memodistance (i-1) j
--                   (c2, ed2) = memodistance (i-1) (j-1)
--                   (c3, ed3) = memodistance i (j-1)
      
--       (cost, edits) = memodistance n m
