import OSS from 'ali-oss';
import { BigNumber, utils } from 'ethers';
import { ethers } from 'hardhat';
import { resolve } from 'path/posix';
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
        return new Promise(async (resolve, reject) => {
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
                resolve(true);
            } catch (e) {
                reject(e);
            }
        });
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
        return new Promise(async (resolve, reject) => {
            try {
                const hnClass = getRandomNumber(hnId, 'class', 1, 4);
                const hashrates = await hn.getHashrates(hnId);
                const className = ['Cavalryman', 'Holy', 'Blade', 'Hex'];
                const heroName = ['Main Tank', 'Lady', 'Hunter', `Golden`];
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
                resolve(true);
            } catch (e) {
                reject(e);
            }
        });
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

    async function generateAllLevelImagesAndMetadatas(imagesCid: string, hnId: number) {
        return new Promise((resolve, reject) => {
            generateAllLevelImages(hnId).then(() => {
                generateAllLevelMetadatas(imagesCid, hnId).then(() => {
                    resolve(true);
                }).catch((e) => {
                    reject(e);
                });
            }).catch((e) => {
                reject(e);
            });
        });
    }

    function updateMetadata() {
        hn.on('SpawnHn', async (to, hnId, event) => {
            generateAllLevelMetadatas('https://cdn.hashland.com/nft/images', hnId);
            console.log(`Spawn NFT #${hnId} to ${to}`);
        });

        hn.on('SetHashrates', async (hnId, hashrates, event) => {
            generateAllLevelMetadatas('https://cdn.hashland.com/nft/images', hnId);
            console.log(`Set NFT #${hnId} hashrates to [${(hashrates[0] / 1e4).toFixed(4)}, ${(hashrates[1] / 1e4).toFixed(4)}]`);
        });

        hn.on('RenameHn', async (hnId, name, event) => {
            generateAllLevelMetadatas('https://cdn.hashland.com/nft/images', hnId);
            console.log(`Set NFT #${hnId} name to ${name}`);
        });
    }

    const start = 47000;
    const end = 49000;
    const batch = 10;
    const set: Set<number> = new Set();
    for (let i = start; i < end; i++) {
        set.add(i);
    }

    async function uploadAllImagesAndMetadatas() {
        return new Promise(resolve => {
            const iterator = set.values();
            let count = 0;
            for (let i = 0; i < batch; i++) {
                const hnId = iterator.next();
                if (hnId.done) {
                    break;
                }
                generateAllLevelImagesAndMetadatas('https://cdn.hashland.com/nft/images', hnId.value).then(() => {
                    set.delete(hnId.value);
                    console.log(`(${end - start - set.size}/${end - start}) NFT #${hnId.value} datas uploaded successfully`);
                }).catch(e => {
                    console.log(`(${end - start - set.size}/${end - start}) NFT #${hnId.value} datas uploaded failed`);
                }).finally(async () => {
                    count++;
                    if (count == batch) {
                        resolve(await uploadAllImagesAndMetadatas());
                    }
                });
            }
        });
    }

    updateMetadata();
    // await uploadAllImagesAndMetadatas();
}

main();
