module Algorithm.JPS where

import           Algorithm.JPS.Astar
import           Algorithm.JPS.Grid

findPathJPS :: Grid -> Int -> Int -> [Int]
findPathJPS g start finish =
  let
    pf            = newPathfinding g start finish
    startnode     = (SearchNode Nothing start C 0)
    (result, pf') = astar expandJPS heuristicJPS pf startnode
  in
    case result of
      Nothing -> []
      Just sn -> unwindJPS pf' sn

unwindJPS :: Pathfinding -> SearchNode -> [Int]
unwindJPS pf (SearchNode prev i dir depth) =
  case prev of
    Nothing -> [i]
    Just sn -> let (SearchNode _ p backdir _) = sn in
      (unwindBetween (dims $ grid pf) (opposite backdir) i p) ++ unwindJPS pf sn

unwindBetween :: GridDims -> Direction -> Int -> Int -> [Int]
unwindBetween d dir s f
  | s == f               = [ ]
  | dir == C             = [s]
  | not (isInBounds d s) = error $ "JPS path unwinding went out of bounds!"
  | otherwise            = s : unwindBetween d dir (moveInDirection d dir s) f

-- Gets direction of dest relative to src
pairToDirection :: GridDims -> Int -> Int -> Direction
pairToDirection d src dest
  | dest == (n d src)  = N
  | dest == (ne d src) = NE
  | dest == (e d src)  = E
  | dest == (se d src) = SE
  | dest == (s d src)  = S
  | dest == (sw d src) = SW
  | dest == (w d src)  = W
  | dest == (nw d src) = NW
  | otherwise          = C

-- Figurs out which direction to scan in and proceed
expandJPS :: ExpandFn
expandJPS pf sn =
  case dir of
    C -> normalExpand pf sn
    _ -> scan pf sn
  where
    SearchNode prev curr dir depth = sn

scan :: Pathfinding -> SearchNode -> [SearchNode]
scan pf sn
  | dir `elem` [N, E, S, W]  = scanStraight pf sn c depth
  | otherwise                = scanDiag pf sn c depth
  where
    SearchNode p c dir depth = sn

heuristicJPS :: HeuristicFn
heuristicJPS = normalHeuristic

-- Diagonal scan does not need to check for forced neighbors -- the straight scans that it spawns
-- will catch them! COOL!!!
scanDiag :: Pathfinding -> SearchNode -> Int -> Int -> [SearchNode]
scanDiag pf sn i dep
  | isBlocked g i  = [ ]
  | isFinish  pf i = [(SearchNode (Just sn) i C 0)]
  | otherwise      =
      if null stScans
         then (scanDiag pf sn (moveInDirection d diag i) (dep + 1))
         else stScans ++
           [(SearchNode (Just sn) (moveInDirection d diag i) diag (dep + 1))]
  where
    g        = grid pf
    d        = dims g
    diag     = dir sn
    (f1, f2) = fortyfives diag
    stScans  = scanStraight pf (SearchNode (Just sn) i f1 dep) i dep
            ++ scanStraight pf (SearchNode (Just sn) i f2 dep) i dep

scanStraight :: Pathfinding -> SearchNode -> Int -> Int -> [SearchNode]
scanStraight pf sn i dep
  | (isBlocked g i)                        = [ ]
  | (isFinish  pf i)                       = [(SearchNode (Just sn) i C 0)]
  | hasForcedNeighborsStraight g forward i =
      forcedNeighborsStraight g sn i forward dep
  | otherwise                              =
      scanStraight pf sn (moveInDirection d forward i) (dep + 1)
  where
    g = grid pf
    d = dims g
    SearchNode prev st forward _ = sn

hasForcedNeighborsStraight :: Grid -> Direction -> Int -> Bool
hasForcedNeighborsStraight g forward i
    = isBlocked g (moveInDirection d d1 i)
   || isBlocked g (moveInDirection d d2 i)
  where
    (d1, d2) = nineties forward
    d = dims g

forcedNeighborsStraight
    :: Grid
    -> SearchNode
    -> Int
    -> Direction
    -> Int
    -> [SearchNode]
forcedNeighborsStraight g sn i forward dep = continue ++ forced1 ++ forced2
  where
    (d1, d2) = nineties forward
    continue = createSN g sn i forward dep
    forced1  = createSNIfBlocked g sn i d1 (between forward d1) dep
    forced2  = createSNIfBlocked g sn i d2 (between forward d2) dep

createSNIfBlocked
    :: Grid
    -> SearchNode
    -> Int
    -> Direction
    -> Direction
    -> Int
    -> [SearchNode]
createSNIfBlocked g prev i blockdir targetdir depth =
    if isBlocked g blocksq && not (isBlocked g targetsq)
       then [SearchNode (Just sn) targetsq targetdir (depth + 1)]
       else []
  where
    d        = dims g
    blocksq  = moveInDirection d blockdir i
    targetsq = moveInDirection d targetdir i
    sn       = (SearchNode (Just prev) i targetdir depth)

createSN :: Grid -> SearchNode -> Int -> Direction -> Int -> [SearchNode]
createSN g prev i dir depth =
    if isBlocked g t
       then []
       else [SearchNode (Just sn) t dir (depth + 1)]
  where
    d  = dims g
    t  = moveInDirection d dir i
    sn = (SearchNode (Just prev) i dir depth)

