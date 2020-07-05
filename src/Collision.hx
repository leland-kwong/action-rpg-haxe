class Collision {
  /* 
     Returns a new endpoint that stops at the first
     circle that it collides with.
   */
  public static function beamCircleIntersectTest(
      startPoint: h2d.col.Point, 
      desiredEndPoint: h2d.col.Point, 
      collisionCircle: h2d.col.Circle,
      lineThickness: Float,
      ?debugGraphics: h2d.Graphics
      ) {
    var actualRadius = collisionCircle.ray;
    /*
       Since we're doing a collision test against a line, we need to extend the collision
       circle's radius with the beam's thickness.
     */
    var fakeCircle = new h2d.col.Circle(collisionCircle.x, collisionCircle.y, actualRadius + lineThickness / 2);
    var line = new h2d.col.Line(
        startPoint,
        desiredEndPoint
        );
    var coarseIntersections = fakeCircle.lineIntersect(line.p1, line.p2);
    var circlePt = new h2d.col.Point(collisionCircle.x, collisionCircle.y);
    var endPtCollisionDist = line.p2.distance(circlePt) - lineThickness / 2;
    var normalCollisionPoint = line.project(circlePt);
    var normalCollisionDist = normalCollisionPoint.distance(circlePt) - lineThickness / 2;
    var distToNormalColPt = line.p1.distance(normalCollisionPoint) - lineThickness / 2 - actualRadius;
    var length = line.length();
    var min = actualRadius;
    var penetrationDist = length > distToNormalColPt
      ? Math.max(0, min - normalCollisionDist)
      : Math.max(0, min - endPtCollisionDist);
    var isCollided = penetrationDist > 0 && distToNormalColPt <= length;
    var cutOffPoint = new h2d.col.Point(
        isCollided ? coarseIntersections[0].x : line.p2.x,
        isCollided ? coarseIntersections[0].y : line.p2.y
        );

    if (debugGraphics != null) {
      var g = debugGraphics;

      g.lineStyle(lineThickness, Game.Colors.pureWhite, 0.3);
      g.moveTo(line.p1.x, line.p1.y);
      g.lineTo(cutOffPoint.x, cutOffPoint.y);

      g.lineStyle(1, Game.Colors.pureWhite);
      g.moveTo(line.p1.x, line.p1.y);
      g.lineTo(line.p2.x, line.p2.y);

      g.beginFill(isCollided ? Game.Colors.green : 0xffffff, 0.7);
      g.drawCircle(collisionCircle.x, collisionCircle.y, actualRadius);

      g.lineStyle(0);
      if (isCollided) {
        // draw intersection points
        g.beginFill(Game.Colors.yellow, 0.8);
        var i = coarseIntersections;
        g.drawCircle(
            i[0].x,
            i[0].y,
            5
            );
        g.drawCircle(
            i[1].x,
            i[1].y,
            5
            );

        g.drawCircle(
            normalCollisionPoint.x,
            normalCollisionPoint.y,
            5
            );
      }

      if (cutOffPoint != null) {
        g.drawCircle(
            cutOffPoint.x,
            cutOffPoint.y,
            lineThickness / 2
            );
      }
    }

    return cutOffPoint;
  }
}
