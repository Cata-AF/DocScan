extends RefCounted
class_name ICFormats

const header_title = """
    <w:p>
        <w:pPr>
            <w:spacing w:line="240" w:lineRule="exact" />
            <w:jc w:val="right" />
            <w:rPr>
                <w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial" />
                <w:b />
                <w:i />
                <w:color w:val="666699" />
                <w:sz w:val="22" />
                <w:szCs w:val="22" />
            </w:rPr>
        </w:pPr>
        <w:r>
            <w:rPr>
                <w:b w:val="on" />
                <w:i w:val="on" />
                <w:color w:val="666699" />
                <w:rFonts w:ascii="Arial" w:hAnsi="Arial" w:cs="Arial" w:eastAsia="Arial" />
                <w:sz w:val="22" />
            </w:rPr>
            <w:t>%s</w:t>
        </w:r>
    </w:p>
"""

const bold_text_format = """
    <w:p w14:paraId="2942FB5B" w14:textId="77777777" w:rsidR="00CA4CB8" w:rsidRPr="00CA4CB8"
        w:rsidRDefault="00CA4CB8" w:rsidP="00CA4CB8">
        <w:pPr>
            <w:rPr>
                <w:b />
                <w:bCs />
                <w:lang w:eastAsia="en-US" />
            </w:rPr>
        </w:pPr>
        <w:bookmarkStart w:id="60" w:name="_Hlk207032910" />
        <w:bookmarkStart w:id="61" w:name="_Hlk201333960" />
        <w:bookmarkStart w:id="62" w:name="_Hlk190854689" />
        <w:r w:rsidRPr="00CA4CB8">
            <w:rPr>
                <w:b />
                <w:bCs />
                <w:lang w:eastAsia="en-US" />
            </w:rPr>
            <w:t>%s</w:t>
        </w:r>
    </w:p>
"""


const table_site_list_format = """
	<w:tbl>
        <w:tblPr>
            <w:tblW w:w="5610" w:type="dxa" />
            <w:tblLook w:val="04A0" w:firstRow="1" w:lastRow="0" w:firstColumn="1"
                w:lastColumn="0" w:noHBand="0" w:noVBand="1" />
        </w:tblPr>
        <w:tblGrid>
            <w:gridCol w:w="1710" />
            <w:gridCol w:w="3900" />
        </w:tblGrid>
        <w:tr w:rsidR="00CA4CB8" w:rsidRPr="00CA4CB8" w14:paraId="2D6FCEA0"
            w14:textId="77777777" w:rsidTr="005D4A74">
            <w:trPr>
                <w:trHeight w:val="510" />
            </w:trPr>
            <w:tc>
                <w:tcPr>
                    <w:tcW w:w="1710" w:type="dxa" />
                    <w:tcBorders>
                        <w:top w:val="single" w:sz="4" w:space="0" w:color="000000" />
                        <w:left w:val="single" w:sz="4" w:space="0" w:color="000000" />
                        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000" />
                        <w:right w:val="single" w:sz="4" w:space="0" w:color="000000" />
                    </w:tcBorders>
                    <w:shd w:val="clear" w:color="auto" w:fill="FFFF00" />
                    <w:noWrap />
                    <w:vAlign w:val="center" />
                    <w:hideMark />
                </w:tcPr>
                <w:p w14:paraId="09B1A7C8" w14:textId="77777777" w:rsidR="00CA4CB8"
                    w:rsidRPr="00CA4CB8" w:rsidRDefault="00CA4CB8" w:rsidP="00CA4CB8">
                    <w:pPr>
                        <w:rPr>
                            <w:b />
                            <w:bCs />
                            <w:lang w:eastAsia="en-US" />
                        </w:rPr>
                    </w:pPr>
                    <w:bookmarkStart w:id="63" w:name="_Hlk207024138" />
                    <w:r w:rsidRPr="00CA4CB8">
                        <w:rPr>
                            <w:b />
                            <w:bCs />
                            <w:lang w:eastAsia="en-US" />
                        </w:rPr>
                        <w:t>Site Name</w:t>
                    </w:r>
                </w:p>
            </w:tc>
            <w:tc>
                <w:tcPr>
                    <w:tcW w:w="3900" w:type="dxa" />
                    <w:tcBorders>
                        <w:top w:val="single" w:sz="4" w:space="0" w:color="000000" />
                        <w:left w:val="single" w:sz="4" w:space="0" w:color="000000" />
                        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000" />
                        <w:right w:val="single" w:sz="4" w:space="0" w:color="000000" />
                    </w:tcBorders>
                    <w:shd w:val="clear" w:color="auto" w:fill="FFFF00" />
                    <w:noWrap />
                    <w:vAlign w:val="center" />
                    <w:hideMark />
                </w:tcPr>
                <w:p w14:paraId="7F7E5AD6" w14:textId="77777777" w:rsidR="00CA4CB8"
                    w:rsidRPr="00CA4CB8" w:rsidRDefault="00CA4CB8" w:rsidP="00CA4CB8">
                    <w:pPr>
                        <w:rPr>
                            <w:b />
                            <w:bCs />
                            <w:lang w:eastAsia="en-US" />
                        </w:rPr>
                    </w:pPr>
                    <w:r w:rsidRPr="00CA4CB8">
                        <w:rPr>
                            <w:b />
                            <w:bCs />
                            <w:lang w:eastAsia="en-US" />
                        </w:rPr>
                        <w:t>DUID</w:t>
                    </w:r>
                </w:p>
            </w:tc>
        </w:tr>
        <w:tr w:rsidR="00CA4CB8" w:rsidRPr="00CA4CB8" w14:paraId="3004F92B"
            w14:textId="77777777" w:rsidTr="005D4A74">
            <w:trPr>
                <w:trHeight w:val="255" />
            </w:trPr>
            <w:tc>
                <w:tcPr>
                    <w:tcW w:w="1710" w:type="dxa" />
                    <w:tcBorders>
                        <w:top w:val="single" w:sz="4" w:space="0" w:color="000000" />
                        <w:left w:val="single" w:sz="4" w:space="0" w:color="000000" />
                        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000" />
                        <w:right w:val="single" w:sz="4" w:space="0" w:color="000000" />
                    </w:tcBorders>
                    <w:shd w:val="clear" w:color="auto" w:fill="auto" />
                    <w:noWrap />
                    <w:vAlign w:val="center" />
                    <w:hideMark />
                </w:tcPr>
                <w:p w14:paraId="35568A32" w14:textId="77777777" w:rsidR="00CA4CB8"
                    w:rsidRPr="00CA4CB8" w:rsidRDefault="00CA4CB8" w:rsidP="00CA4CB8">
                    <w:pPr>
                        <w:rPr>
                            <w:lang w:eastAsia="en-US" />
                        </w:rPr>
                    </w:pPr>
                    <w:r w:rsidRPr="00CA4CB8">
                        <w:rPr>
                            <w:lang w:eastAsia="en-US" />
                        </w:rPr>
                        <w:t>%s</w:t>
                    </w:r>
                </w:p>
            </w:tc>
            <w:tc>
                <w:tcPr>
                    <w:tcW w:w="3900" w:type="dxa" />
                    <w:tcBorders>
                        <w:top w:val="single" w:sz="4" w:space="0" w:color="000000" />
                        <w:left w:val="single" w:sz="4" w:space="0" w:color="000000" />
                        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="000000" />
                        <w:right w:val="single" w:sz="4" w:space="0" w:color="000000" />
                    </w:tcBorders>
                    <w:shd w:val="clear" w:color="auto" w:fill="auto" />
                    <w:noWrap />
                    <w:vAlign w:val="center" />
                    <w:hideMark />
                </w:tcPr>
                <w:p w14:paraId="5400713C" w14:textId="77777777" w:rsidR="00CA4CB8"
                    w:rsidRPr="00CA4CB8" w:rsidRDefault="00CA4CB8" w:rsidP="00CA4CB8">
                    <w:pPr>
                        <w:rPr>
                            <w:lang w:eastAsia="en-US" />
                        </w:rPr>
                    </w:pPr>
                    <w:r w:rsidRPr="00CA4CB8">
                        <w:rPr>
                            <w:lang w:eastAsia="en-US" />
                        </w:rPr>
                        <w:t>%s</w:t>
                    </w:r>
                </w:p>
            </w:tc>
        </w:tr>
        <w:bookmarkEnd w:id="60" />
        <w:bookmarkEnd w:id="63" />
    </w:tbl>
"""

const line_entry = """
    <w:p>
        <w:r>
			<w:tab/>
            <w:t>%s</w:t>
        </w:r>
    </w:p>
"""
