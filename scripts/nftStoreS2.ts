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
        return new Promise(async (resolve, reject) => {
            try {
                const series = 2;
                const hnClass = getRandomNumber(hnId, 'class', 1, 4);

                const heroItems = [
                    `nft/s${series}/class${hnClass}/hero.png`,
                    `nft/s${series}/class${hnClass}/item1/${getRandomNumber(hnId, 'item1', 1, 10)}.png`,
                    `nft/s${series}/class${hnClass}/item2/${getRandomNumber(hnId, 'item2', 1, 10)}.png`,
                    `nft/s${series}/class${hnClass}/item3/${getRandomNumber(hnId, 'item3', 1, 10)}.png`,
                    `nft/s${series}/class${hnClass}/item4/${getRandomNumber(hnId, 'item4', 1, 10)}.png`,
                    `nft/s${series}/class${hnClass}/item5/${getRandomNumber(hnId, 'item5', 1, 10)}.png`,
                    `nft/s${series}/class${hnClass}/item6/${getRandomNumber(hnId, 'item6', 1, 10)}.png`,
                    `nft/s${series}/class${hnClass}/item7/${getRandomNumber(hnId, 'item7', 1, 10)}.png`,
                    `nft/s${series}/class${hnClass}/item8/${getRandomNumber(hnId, 'item8', 1, 10)}.png`,
                ];

                const heroItemsByLevel = [
                    [],
                    hnClass == 1 ? [heroItems[0], heroItems[2], heroItems[1]] : [heroItems[0], heroItems[1], heroItems[2]],
                    hnClass == 1 ? [heroItems[0], heroItems[3], heroItems[4], heroItems[1]] : [heroItems[0], heroItems[1], heroItems[3], heroItems[4]],
                    hnClass == 1 ? [heroItems[0], heroItems[3], heroItems[5], heroItems[6], heroItems[1]] : [heroItems[0], heroItems[1], heroItems[3], heroItems[5], heroItems[6]],
                    hnClass == 1 ? [heroItems[0], heroItems[3], heroItems[5], heroItems[6], heroItems[7], heroItems[1]] : hnClass == 3 ? [heroItems[0], heroItems[1], heroItems[7], heroItems[3], heroItems[5], heroItems[6]] : [heroItems[0], heroItems[1], heroItems[3], heroItems[5], heroItems[6], heroItems[7]],
                    hnClass == 1 ? [heroItems[0], heroItems[3], heroItems[5], heroItems[6], heroItems[7], heroItems[1], heroItems[8]] : hnClass == 3 ? [heroItems[0], heroItems[1], heroItems[7], heroItems[3], heroItems[5], heroItems[6], heroItems[8]] : [heroItems[0], heroItems[1], heroItems[3], heroItems[5], heroItems[6], heroItems[7], heroItems[8]],
                ];

                const bg = sharp(`nft/s${series}/bg/${level}.png`).toBuffer();
                const materials = [
                    `nft/s${series}/class${hnClass}/effect/bg/${level}.png`,
                    ...heroItemsByLevel[level],
                    `nft/s${series}/class${hnClass}/info.png`,
                    `nft/s${series}/bar/${level}.png`,
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
                const ultra = (await hn.data(hnId, 'ultra')) == 1 ? true : false;
                const className = ['Cavalryman', 'Holy', 'Blade', 'Hex'];
                const heroName = ['Tameka', 'Katniss', 'Natalie', `Mila`];
                const fileName = `hashland-nft-${hnId}-${level}`;

                const hcHashrate = `watermark,text_${Buffer.from((hashrates[0] / 1e4).toFixed(4)).toString('base64url')},type_enpnZnhpbmd5YW4,color_ffffff,size_24,g_nw,x_395,y_79`;
                const ultraLogo = ultra ? `/watermark,image_${Buffer.from('https://cdn.hashland.com/nft/logo/ultra_1024.png').toString('base64url')},g_center` : ``;

                const metadata = {
                    name: `HashLand NFT #${hnId}`,
                    description: 'The NFTs with BTC hashrate have been sold out. Why not and cherish the last batch of NFTs with HC hashrate? The 2nd batch of Hashland NFTs with HC hashrate and strong hero attributes in game.',
                    image: `${imagesCid}/${fileName}.png?image_process=${hcHashrate}${ultraLogo}`,
                    attributes: [
                        {
                            trait_type: 'Ip',
                            value: `Hash Warfare`,
                        },
                        {
                            trait_type: 'Series',
                            value: 'Series 2',
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
                            trait_type: 'Ultra',
                            value: ultra,
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
            if (hnId >= 60000) {
                generateAllLevelMetadatas('https://cdn.hashland.com/nft/images', hnId);
                console.log(`Spawn NFT #${hnId} to ${to}`);
            }
        });

        hn.on('SetHashrates', async (hnId, hashrates, event) => {
            if (hnId >= 60000) {
                generateAllLevelMetadatas('https://cdn.hashland.com/nft/images', hnId);
                console.log(`Set NFT #${hnId} hashrates to [${(hashrates[0] / 1e4).toFixed(4)}, ${(hashrates[1] / 1e4).toFixed(4)}]`);
            }
        });

        const filter = hn.filters.Transfer(null, '0xe0A9e5B59701a776575fDd6257c3F89Ae362629a');
        hn.on(filter, async (from, to, hnId, event) => {
            if (hnId >= 60000) {
                generateAllLevelMetadatas('https://cdn.hashland.com/nft/images', hnId);
                console.log(`Transfer NFT #${hnId} from ${from} to Binance NFT Market`);
            }
        });
    }

    const start = 60000;
    const end = 65000;
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

    // updateMetadata();
    await uploadAllImagesAndMetadatas();
}

main();
