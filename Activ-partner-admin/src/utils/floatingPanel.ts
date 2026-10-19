export interface PanelAnchor { left: number; right: number; top: number; bottom: number; width: number }
export interface PanelViewport { left: number; top: number; width: number; height: number }

export function floatingPanel(anchor: PanelAnchor, viewport: PanelViewport) {
  const gap = 6;
  const edge = 8;
  const topEdge = viewport.top + edge;
  const bottomEdge = viewport.top + viewport.height - edge;
  const anchorTop = Math.max(topEdge, Math.min(anchor.top, bottomEdge));
  const anchorBottom = Math.max(topEdge, Math.min(anchor.bottom, bottomEdge));
  const below = bottomEdge - anchorBottom - gap;
  const above = anchorTop - topEdge - gap;
  const opensUp = below < 240 && above > below;
  const width = Math.min(anchor.width, Math.max(0, viewport.width - edge * 2));
  return {
    left: Math.max(viewport.left + edge, Math.min(anchor.left, viewport.left + viewport.width - width - edge)),
    top: opensUp ? anchorTop - gap : anchorBottom + gap,
    width,
    maxHeight: Math.max(0, Math.min(280, opensUp ? above : below)),
    opensUp,
  };
}
