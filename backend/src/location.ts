/**
 * Approximate areas and distance bands. The same grid is implemented in the
 * app (lib/domain/location_grid.dart): keep the two identical.
 */

/** Cell height in degrees of latitude: about 2 km. */
export const cellDegrees = 0.018;

/** Roughly how wide a cell is, for explanations. */
export const cellKm = 2;

export interface Cell {
  lat: number;
  lng: number;
}

const round6 = (x: number) => Math.round(x * 1e6) / 1e6;

/** The centre of the grid cell that holds a point. Cells are ~2 km each way. */
export function snapToCell(lat: number, lng: number): Cell {
  const row = Math.floor(lat / cellDegrees);
  const centreLat = Math.min(89.99, Math.max(-89.99, (row + 0.5) * cellDegrees));
  const lngStep = cellDegrees / Math.max(Math.cos((centreLat * Math.PI) / 180), 0.01);
  const wrapped = ((((lng + 180) % 360) + 360) % 360) - 180;
  const col = Math.floor(wrapped / lngStep);
  // Columns count from 0 degrees, so the ones at the date line run past +/-180;
  // keep the centre a valid longitude.
  let centreLng = (col + 0.5) * lngStep;
  if (centreLng > 180) centreLng -= 360;
  if (centreLng < -180) centreLng += 360;
  return { lat: round6(centreLat), lng: round6(centreLng) };
}

export function distanceKm(a: Cell, b: Cell): number {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLng = (b.lng - a.lng) * rad;
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.min(1, Math.sqrt(h)));
}

/** Wide bands on purpose: the same cell or the next one both read "Under 5 km". */
export function distanceBand(km: number): string {
  if (km < 5) return 'Under 5 km away';
  if (km < 10) return '5\u201310 km away';
  if (km < 25) return '10\u201325 km away';
  if (km < 50) return '25\u201350 km away';
  if (km < 100) return '50\u2013100 km away';
  return 'Over 100 km away';
}

/** A different area is accepted at most this often, which limits triangulation. */
export const moveIntervalSeconds = 15 * 60;

/** Faster than an airliner means a made-up location. */
export const maxSpeedKmh = 1000;
