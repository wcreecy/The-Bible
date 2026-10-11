# KJV text fixes — review sheet

`The Bible/kjv.json` now has **31,102 verses**, matching the standard KJV (31,102).

Fixed by `Scripts/fix_kjv_versification.py`. Every chapter was compared against an independent KJV text ([aruljohn/Bible-kjv](https://github.com/aruljohn/Bible-kjv)); these were the only places where verse numbering differed.

**Notes**

- Restored verses use standard KJV (1769) wording. They don't have the supplied-word (italic) markup or translators' footnotes that other verses carry, because the source used doesn't record them.
- Words of Jesus in restored verses are marked red-letter, matching the verses around them.
- Saved bookmarks, favorites, notes, and highlights in the affected chapters were stored by verse number, so any saved after a gap now point to the verse with that (correct) number.

## Missing verses restored (6)

### Matthew 2:16 — missing verse restored

**Added:** Then Herod, when he saw that he was mocked of the wise men, was exceeding wroth, and sent forth, and slew all the children that were in Bethlehem, and in all the coasts thereof, from two years old and under, according to the time which he had diligently enquired of the wise men.

Every later verse in Matthew 2 moves up by one, so verse 16 through the end of the chapter now carries its correct number (the chapter now has 23 verses).

### Matthew 22:1 — missing verse restored

**Added:** And Jesus answered and spake unto them again by parables, and said,

Every later verse in Matthew 22 moves up by one, so verse 1 through the end of the chapter now carries its correct number (the chapter now has 46 verses).

### Matthew 26:38 — missing verse restored

**Added:** Then saith he unto them, My soul is exceeding sorrowful, even unto death: tarry ye here, and watch with me.

Every later verse in Matthew 26 moves up by one, so verse 38 through the end of the chapter now carries its correct number (the chapter now has 75 verses).

### Mark 4:40 — missing verse restored

**Added:** And he said unto them, Why are ye so fearful? how is it that ye have no faith?

Every later verse in Mark 4 moves up by one, so verse 40 through the end of the chapter now carries its correct number (the chapter now has 41 verses).

### Mark 7:11 — missing verse restored

**Added:** But ye say, If a man shall say to his father or mother, It is Corban, that is to say, a gift, by whatsoever thou mightest be profited by me; he shall be free.

Every later verse in Mark 7 moves up by one, so verse 11 through the end of the chapter now carries its correct number (the chapter now has 37 verses).

### Mark 8:8 — missing verse restored

**Added:** So they did eat, and were filled: and they took up of the broken meat that was left seven baskets.

Every later verse in Mark 8 moves up by one, so verse 8 through the end of the chapter now carries its correct number (the chapter now has 38 verses).

## Split verses re-joined (4)

### 1 Samuel 20:42 — split verse re-joined

**Before:** 1 Samuel 20:42 — And Jonathan said to David, Go in peace, forasmuch as we have sworn both of us in the name of the LORD, saying, The LORD be between me and thee, and between my seed and thy seed for ever.

1 Samuel 20:43 — And he arose and departed: and Jonathan went into the city.

**After:** 1 Samuel 20:42 — And Jonathan said to David, Go in peace, forasmuch as we have sworn both of us in the name of the LORD, saying, The LORD be between me and thee, and between my seed and thy seed for ever. And he arose and departed: and Jonathan went into the city.

The chapter now has 42 verses.

### 1 Kings 22:43 — split verse re-joined

**Before:** 1 Kings 22:43 — And he walked in all the ways of Asa his father; he turned not aside from it, doing that which was right in the eyes of the LORD:

1 Kings 22:44 — Nevertheless the high places were not taken away; for the people offered and burnt incense yet in the high places.

**After:** 1 Kings 22:43 — And he walked in all the ways of Asa his father; he turned not aside from it, doing that which was right in the eyes of the LORD: nevertheless the high places were not taken away; for the people offered and burnt incense yet in the high places.

The chapter now has 53 verses.

### 3 John 1:14 — split verse re-joined

**Before:** 3 John 1:14 — But I trust I shall shortly see thee, and we shall speak face to face.

3 John 1:15 — Peace be to thee. Our friends salute thee. Greet the friends by name.

**After:** 3 John 1:14 — But I trust I shall shortly see thee, and we shall speak face to face. Peace be to thee. Our friends salute thee. Greet the friends by name.

The chapter now has 14 verses.

### Revelation 12:18 / 13:1 — split verse re-joined

**Before:** Revelation 12:18 — And I stood upon the sand of the sea.

Revelation 13:1 — And saw a beast rise up out of the sea, having seven heads and ten horns, and upon his horns ten crowns, and upon his heads the name of blasphemy.

**After:** Revelation 13:1 — And I stood upon the sand of the sea, and saw a beast rise up out of the sea, having seven heads and ten horns, and upon his horns ten crowns, and upon his heads the name of blasphemy.

Revelation 12 now ends at verse 17, as in the KJV.
