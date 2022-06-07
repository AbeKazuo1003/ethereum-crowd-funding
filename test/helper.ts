export function getTimestamp(date: Date){
    return Math.floor(date.getTime()/1000);
}

export const BEFORE_ONE_HOUR_TIMESTAMP = getTimestamp(new Date()) - 3600;
export const TIMESTAMP_NOW = getTimestamp(new Date());
export const AFTER_ONE_HOUR_TIMESTAMP = getTimestamp(new Date()) + 3600;
