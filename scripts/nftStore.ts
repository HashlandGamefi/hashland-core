// import { NFTStorage, File } from 'nft.storage';
import OSS from 'ali-oss';
import { BigNumber, utils } from 'ethers';
import sharp from 'sharp';

const maxLevel = 5;

// const client = new NFTStorage({ token: process.env.NFT_STORAGE_API_KEY as string });

const client = new OSS({
    region: 'oss-ap-southeast-1',
    accessKeyId: process.env.accessKeyId as string,
    accessKeySecret: process.env.accessKeySecret as string,
    bucket: 'hashlandgamefi',
});

function getRandomNumber(hnId: number, slot: string, base: number, range: number) {
    return BigNumber.from(utils.solidityKeccak256(['uint256', 'string'], [hnId, slot])).mod(range).add(base).toNumber();
}

async function generateImage(hnId: number, level: number) {
    const hnClass = getRandomNumber(hnId, 'class', 1, 4);

    const heroItems = [
        `nft/class${hnClass}/hero.png`,
        `nft/class${hnClass}/item1/${getRandomNumber(hnId, 'item1', 1, 10)}.png`,
        `nft/class${hnClass}/item2/${getRandomNumber(hnId, 'item2', 1, 10)}.png`,
        `nft/class${hnClass}/item3/${getRandomNumber(hnId, 'item3', 1, 10)}.png`,
        `nft/class${hnClass}/item4/${getRandomNumber(hnId, 'item4', 1, 10)}.png`,
        `nft/class${hnClass}/item5/${getRandomNumber(hnId, 'item5', 1, 10)}.png`,
        `nft/class${hnClass}/item6/${getRandomNumber(hnId, 'item6', 1, 10)}.png`,
        `nft/class${hnClass}/item7/${getRandomNumber(hnId, 'item7', 1, 10)}.png`,
    ];

    const heroItemsByLevel = [
        [],
        [heroItems[0], heroItems[1], heroItems[2]],
        [heroItems[0], heroItems[3], heroItems[1], heroItems[2]],
        hnClass == 4 ? [heroItems[0], heroItems[1], heroItems[3], heroItems[4], heroItems[2]] : [heroItems[0], heroItems[3], heroItems[4], heroItems[1], heroItems[2]],
        [heroItems[0], heroItems[3], heroItems[4], heroItems[5], heroItems[6]],
        hnClass == 2 ? [heroItems[7], heroItems[0], heroItems[3], heroItems[4], heroItems[5], heroItems[6]] : [heroItems[0], heroItems[3], heroItems[4], heroItems[5], heroItems[6], heroItems[7]],
    ];

    const bg = sharp(`nft/bg/${level}.png`).toBuffer();
    const materials = [
        `nft/class${hnClass}/effect/bg/${level}.png`,
        ...heroItemsByLevel[level],
        `nft/class${hnClass}/effect/hero/${level}.png`,
        `nft/class${hnClass}/info.png`
    ].reduce(async (input, overlay) => {
        return await sharp(await input).composite([{ input: overlay }]).toBuffer();
    }, bg);

    const composited = await sharp(await materials).sharpen().webp({ quality: 90 }).toBuffer();

    const result = await client.put(`nft/images/hashland-nft-${hnId}-${level}.png`, composited);
    console.log(result.url);
}

async function generateImages(start: number, end: number) {
    return new Promise(resolve => {
        let count = 0;
        for (let hnId = start; hnId < end; hnId++) {
            for (let level = 1; level <= maxLevel; level++) {
                generateImage(hnId, level).then(() => {
                    count++;
                    if (count == (end - start) * maxLevel) {
                        resolve(true);
                    }
                });
            }
        }
    });
}

// async function uploadImages(start: number, end: number) {
//     const images = [];
//     for (let hnId = start; hnId < end; hnId++) {
//         for (let level = 1; level <= maxLevel; level++) {
//             const fileName = `hashland-nft-${hnId}-${level}.png`;
//             const image = Buffer.from(fs.readFileSync(`nft/images/${fileName}`));
//             images.push(new File([image], fileName, { type: 'image/webp' }));
//         }
//     }

//     return await client.storeDirectory(images);
// }

async function generateMetadata(imagesCid: string, hnId: number, level: number) {
    const hnClass = getRandomNumber(hnId, 'class', 1, 4);
    const className = ['Cavalryman', 'Holy', 'Blade', 'Hex'];
    const heroName = ['Main Tank', 'Lady', 'Hunter', `Gul'dan`];
    const fileName = `hashland-nft-${hnId}-${level}`;

    const metadata = {
        name: `Hashland NFT #${hnId}`,
        description: 'Have you ever imagined an NFT with BTC hashrate? HashLand did it, and now he brings the first series of NFT - I AM MT.',
        image: `${imagesCid}/${fileName}.png`,
        attributes: [
            {
                trait_type: 'Ip',
                value: `I AM MT`,
            },
            {
                trait_type: 'Series',
                value: 'Basic',
            },
            {
                trait_type: 'Level',
                value: level,
            },
            {
                trait_type: 'Class',
                value: className[hnClass - 1],
            },
            {
                trait_type: 'Hero',
                value: heroName[hnClass - 1],
            },
        ],
    }

    const result = await client.put(`nft/metadatas/${fileName}.json`, Buffer.from(JSON.stringify(metadata)));
    console.log(result.url);
}

function generateMetadatas(imagesCid: string, start: number, end: number) {
    return new Promise(resolve => {
        let count = 0;
        for (let hnId = start; hnId < end; hnId++) {
            for (let level = 1; level <= maxLevel; level++) {
                generateMetadata(imagesCid, hnId, level).then(() => {
                    count++;
                    if (count == (end - start) * maxLevel) {
                        resolve(true);
                    }
                });
            }
        }
    });
}

// async function uploadMetadatas(start: number, end: number) {
//     const metadatas = [];
//     for (let hnId = start; hnId < end; hnId++) {
//         for (let level = 1; level <= maxLevel; level++) {
//             const fileName = `hashland-nft-${hnId}-${level}.json`;
//             const json = fs.readFileSync(`nft/metadatas/${fileName}`).toString();
//             metadatas.push(new File([json], fileName));
//         }
//     }
//     return await client.storeDirectory(metadatas);
// }

async function main() {
    const start = 100;
    const end = 1000;
    const batch = 10;

    for (let i = start / batch; i < end / batch; i++) {
        await generateImages(i * batch, (i + 1) * batch);
        console.log(`${(i + 1) * batch} / ${end}`);
    }
    // const newImageCID = await uploadImages(start, end);
    // console.log('New Image CID:', newImageCID);

    // for (let i = start / batch; i < end / batch; i++) {
    //     await generateMetadatas('https://cdn.hashland.com/nft/images', i * batch, (i + 1) * batch);
    //     console.log(`${(i + 1) * batch} / ${end}`);
    // }
    // const newMetadataCID = await uploadMetadatas(start, end);
    // console.log('New Metadata CID:', newMetadataCID);
}

main();
