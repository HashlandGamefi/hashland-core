import OSS from 'ali-oss';
import { BigNumber, utils } from 'ethers';
import { ethers } from 'hardhat';
import sharp from 'sharp';

const maxLevel = 5;
const hnAddr = '0xEEa8bD31DA9A2169C38968958B6DF216381B0f08'

const client = new OSS({
    region: 'oss-ap-southeast-1',
    accessKeyId: process.env.accessKeyId as string,
    accessKeySecret: process.env.accessKeySecret as string,
    bucket: 'hashlandgamefi',
});

function getRandomNumber(hnId: number, slot: string, base: number, range: number) {
    return BigNumber.from(utils.solidityKeccak256(['uint256', 'string'], [hnId, slot])).mod(range).add(base).toNumber();
}

async function main() {
    const hn = await ethers.getContractAt('HN', hnAddr);

    async function generateImageByLevel(hnId: number, level: number) {
        try {
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
                hnClass == 4 ? [heroItems[0], heroItems[1], heroItems[3], heroItems[2]] : [heroItems[0], heroItems[3], heroItems[1], heroItems[2]],
                hnClass == 4 ? [heroItems[0], heroItems[1], heroItems[3], heroItems[4], heroItems[2]] : [heroItems[0], heroItems[3], heroItems[4], heroItems[1], heroItems[2]],
                [heroItems[0], heroItems[3], heroItems[4], heroItems[5], heroItems[6]],
                hnClass == 2 ? [heroItems[7], heroItems[0], heroItems[3], heroItems[4], heroItems[5], heroItems[6]] : [heroItems[0], heroItems[3], heroItems[4], heroItems[5], heroItems[6], heroItems[7]],
            ];

            const bg = sharp(`nft/bg/${level}.png`).toBuffer();
            const materials = [
                `nft/class${hnClass}/effect/bg/${level}.png`,
                ...heroItemsByLevel[level],
                `nft/class${hnClass}/effect/hero/${level}.png`,
                `nft/class${hnClass}/info.png`,
                `nft/bar/${level}.png`,
            ].reduce(async (input, overlay) => {
                return await sharp(await input).composite([{ input: overlay }]).toBuffer();
            }, bg);

            const composited = await sharp(await materials).sharpen().webp({ quality: 90 }).toBuffer();

            await client.put(`nft/images/hashland-nft-${hnId}-${level}.png`, composited);
        } catch (e) { }
    }

    async function generateAllLevelImages(hnId: number) {
        return new Promise((resolve, reject) => {
            let count = 0;
            for (let level = 1; level <= maxLevel; level++) {
                generateImageByLevel(hnId, level).then(() => {
                    count++;
                    if (count == maxLevel) {
                        resolve(true);
                    }
                }).catch(e => {
                    reject(e);
                });
            }
        });
    }

    async function generateMetadataByLevel(imagesCid: string, hnId: number, level: number) {
        try {
            const hnClass = getRandomNumber(hnId, 'class', 1, 4);
            const hashrates = await hn.getHashrates(hnId);
            const className = ['Cavalryman', 'Holy', 'Blade', 'Hex'];
            const heroName = ['Main Tank', 'Lady', 'Hunter', `Gul'dan`];
            const fileName = `hashland-nft-${hnId}-${level}`;

            const watermark = `watermark,text_${Buffer.from((hashrates[0] / 1e4).toFixed(4)).toString('base64url')},type_enpnZnhpbmd5YW4,color_ffffff,size_24,g_nw,x_395,y_79/watermark,text_${Buffer.from((hashrates[1] / 1e4).toFixed(4)).toString('base64url')},type_enpnZnhpbmd5YW4,color_ffffff,size_24,g_nw,x_655,y_79`;

            const metadata = {
                name: `HashLand NFT #${hnId}`,
                description: 'Have you ever imagined an NFT with BTC hashrate? HashLand did it, and now he brings the first series of NFT - I AM MT.',
                image: `${imagesCid}/${fileName}.png?image_process=${watermark}`,
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
                    {
                        trait_type: 'HC_Hashrate',
                        value: (hashrates[0] / 1e4).toFixed(4),
                    },
                    {
                        trait_type: 'BTC_Hashrate',
                        value: (hashrates[1] / 1e4).toFixed(4),
                    },
                ],
            }

            await client.put(`nft/metadatas/${fileName}.json`, Buffer.from(JSON.stringify(metadata)));
        } catch (e) { }
    }

    async function generateAllLevelMetadatas(imagesCid: string, hnId: number) {
        return new Promise((resolve, reject) => {
            let count = 0;
            for (let level = 1; level <= maxLevel; level++) {
                generateMetadataByLevel(imagesCid, hnId, level).then(() => {
                    count++;
                    if (count == maxLevel) {
                        resolve(true);
                    }
                }).catch((e) => {
                    reject(e);
                });
            }
        });
    }

    hn.on('SpawnHn', async (to, hnId, event) => {
        const level = (await hn.level(hnId)).toNumber();
        console.log('');
        console.log(`Spawn level-${level} NFT #${hnId} to ${to}`);

        generateMetadataByLevel('https://cdn.hashland.com/nft/images', hnId, level);
    });

    hn.on('SetHashrates', async (hnId, hashrates, event) => {
        const level = (await hn.level(hnId)).toNumber();
        console.log('');
        console.log(`Set level-${level} NFT #${hnId} hashrates to [${(hashrates[0] / 1e4).toFixed(4)}, ${(hashrates[1] / 1e4).toFixed(4)}]`);

        generateMetadataByLevel('https://cdn.hashland.com/nft/images', hnId, level);
    });

    const start = 0;
    const end = 34000;
    const imagesBatch = 100;
    const metadatasBatch = 500;
    const set: Set<number> = new Set();
    for (let i = start; i < end; i++) {
        set.add(i);
    }

    async function uploadAllImages() {
        return new Promise(resolve => {
            const iterator = set.values();
            let count = 0;
            for (let i = 0; i < imagesBatch; i++) {
                const hnId = iterator.next();
                if (hnId.done) {
                    break;
                }
                generateAllLevelImages(hnId.value).then(() => {
                    set.delete(hnId.value);
                    console.log(`NFT #${hnId.value} image uploaded successfully`);
                    if (set.size == 0) {
                        console.log(`All ${end - start} images uploaded successfully`);
                    }
                }).catch(e => {
                    console.log(`NFT #${hnId.value} image uploaded failed`);
                }).finally(async () => {
                    count++;
                    if (count == imagesBatch) {
                        resolve(await uploadAllImages());
                    }
                });
            }
        });
    }
    async function uploadAllMetadatas() {
        return new Promise(resolve => {
            const iterator = set.values();
            let count = 0;
            for (let i = 0; i < metadatasBatch; i++) {
                const hnId = iterator.next();
                if (hnId.done) {
                    break;
                }
                generateAllLevelMetadatas('https://cdn.hashland.com/nft/images', hnId.value).then(() => {
                    set.delete(hnId.value);
                    console.log(`NFT #${hnId.value} metadata uploaded successfully`);
                    if (set.size == 0) {
                        console.log(`All ${end - start} metadatas uploaded successfully`);
                    }
                }).catch(e => {
                    console.log(`NFT #${hnId.value} metadata uploaded failed`);
                }).finally(async () => {
                    count++;
                    if (count == metadatasBatch) {
                        resolve(await uploadAllMetadatas());
                    }
                });
            }
        });
    }
    // await uploadAllImages();
    // await uploadAllMetadatas();
}

main();
