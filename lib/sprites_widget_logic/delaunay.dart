import 'dart:math' as math;

const double EPSILON = 1.0 / 1048576.0;

class MaybeTriangle {
  final int i, j, k;
  final double x, y, r;
  MaybeTriangle({this.i, this.j, this.k, this.x, this.y, this.r});
}

List<List<double>> supertriangle(List<List<double>> vertices) {
  double xmin = double.infinity;
  double ymin = double.infinity;
  double xmax = double.negativeInfinity;
  double ymax = double.negativeInfinity;

  for (List<double> vertex in vertices) {
    if (vertex[0] < xmin) xmin = vertex[0];
    if (vertex[0] > xmax) xmax = vertex[0];
    if (vertex[1] < ymin) ymin = vertex[1];
    if (vertex[1] > ymax) ymax = vertex[1];
  }

  final double dx = xmax - xmin;
  final double dy = ymax - ymin;
  final double dmax = math.max(dx, dy);
  final double xmid = xmin + dx * 0.5;
  final double ymid = ymin + dy * 0.5;

  return [
    [xmid - 20 * dmax, ymid - dmax],
    [xmid, ymid + 20 * dmax],
    [xmid + 20 * dmax, ymid - dmax],
  ];
}

MaybeTriangle circumcircle(List<List<double>> vertices, int i, int j, int k) {
  final double x1 = vertices[i][0];
  final double y1 = vertices[i][1];
  final double x2 = vertices[j][0];
  final double y2 = vertices[j][1];
  final double x3 = vertices[k][0];
  final double y3 = vertices[k][1];
  final double fabsy1y2 = (y1 - y2).abs();
  final double fabsy2y3 = (y2 - y3).abs();

  if (fabsy1y2 < EPSILON && fabsy2y3 < EPSILON) return null;

  double xc;
  double yc;

  if (fabsy1y2 < EPSILON) {
    final double m2 = -((x3 - x2) / (y3 - y2));
    final double mx2 = (x2 + x3) / 2.0;
    final double my2 = (y2 + y3) / 2.0;
    xc = (x2 + x1) / 2.0;
    yc = m2 * (xc - mx2) + my2;
  } else if (fabsy2y3 < EPSILON) {
    final double m1 = -((x2 - x1) / (y2 - y1));
    final double mx1 = (x1 + x2) / 2.0;
    final double my1 = (y1 + y2) / 2.0;
    xc = (x3 + x2) / 2.0;
    yc = m1 * (xc - mx1) + my1;
  } else {
    final double m1 = -((x2 - x1) / (y2 - y1));
    final double m2 = -((x3 - x2) / (y3 - y2));
    final double mx1 = (x1 + x2) / 2.0;
    final double mx2 = (x2 + x3) / 2.0;
    final double my1 = (y1 + y2) / 2.0;
    final double my2 = (y2 + y3) / 2.0;
    xc = (m1 * mx1 - m2 * mx2 + my2 - my1) / (m1 - m2);
    yc = (fabsy1y2 > fabsy2y3) ? m1 * (xc - mx1) + my1 : m2 * (xc - mx2) + my2;
  }

  final double dx = x2 - xc;
  final double dy = y2 - yc;
  return MaybeTriangle(i: i, j: j, k: k, x: xc, y: yc, r: dx * dx + dy * dy);
}

void dedup(List<int> edges) {
  int i, j;
  int a, b, m, n;

  for (j = edges.length; j > 1;) {
    while (j > edges.length) j -= 2;
    if (j < 2) continue;
    b = edges[--j];
    a = edges[--j];

    for (i = j; i > 1;) {
      n = edges[--i];
      m = edges[--i];

      if ((a == m && b == n) || (a == n && b == m)) {
        edges..removeAt(j + 1)..removeAt(j);
        edges..removeAt(i + 1)..removeAt(i);
        break;
      }
    }
  }
}

List<int> triangulate(List<List<double>> vertices) {
  final int n = vertices.length;
  if (n < 3) return [];

  vertices = List.from(vertices);

  final List<int> indices = List(n);
  for (int i = 0; i < indices.length; i++) {
    indices[i] = i;
  }

  indices.sort((int i, int j) {
    final double diff = vertices[j][0] - vertices[i][0];
    return diff == 0.0 ? i - j : diff.round();
  });

  final List<List<double>> st = supertriangle(vertices);
  vertices.addAll([st[0], st[1], st[2]]);

  final MaybeTriangle circCircle = circumcircle(vertices, n + 0, n + 1, n + 2);
  if (circCircle == null) return [];

  List<MaybeTriangle> open = [circumcircle(vertices, n + 0, n + 1, n + 2)];
  List<MaybeTriangle> closed = [];
  List<int> edges = [];

  for (int i = indices.length - 1; i >= 0; i--) {
    edges.length = 0;
    final int c = indices[i];
    for (int j = open.length - 1; j >= 0; j--) {
      final double dx = vertices[c][0] - open[j].x;
      if (dx > 0.0 && dx * dx > open[j].r) {
        closed.add(open[j]);
        open.removeAt(j);
        continue;
      }
      final double dy = vertices[c][1] - open[j].y;
      if (dx * dx + dy * dy - open[j].r > EPSILON) continue;

      edges.addAll([
        open[j].i,
        open[j].j,
        open[j].j,
        open[j].k,
        open[j].k,
        open[j].i,
      ]);
      open.removeAt(j);
    }

    dedup(edges);

    for (int j = edges.length; j >= 2;) {
      final int b = edges[--j];
      final int a = edges[--j];
      open.add(circumcircle(vertices, a, b, c));
    }
  }
  edges.length = 0;

  for (int i = 0; i < open.length; i++) {
    closed.add(open[i]);
  }
  open.length = 0;

  List<int> output = [];
  for (int i = 0; i < closed.length; i++) {
    if (closed[i].i < n && closed[i].j < n && closed[i].k < n) {
      output.addAll([closed[i].i, closed[i].j, closed[i].k]);
    }
  }

  return output;
}
