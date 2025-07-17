# runtests

using GMime
using Test, Dates

function gen_received_string(date::String, tzoneoffset::String="+0000", tzone::String="UTC")
    return """Received:        from 1testtests.com (1testtests.com [123.11.11.11])          by 1testtests with SMTPS id 1testtests;        $date $tzoneoffset $tzone\n"""
end

function gen_email_string(
    date::String, 
    tzoneoffset::String="+0000",
    tzone::String="UTC",
    received::String=""
)
    return """MIME-Version: 1.0
    $(received)Date: $date $tzoneoffset $tzone 
    Message-ID: <CAOU+8LMfxVaPMmigMQE2qTBLSbNdKQVps=Fi0S3X8LnfxT2xee@mail.email.com>
    Subject: Test Message
    From: Test User <username@example.com>
    To: Test User <username@example.com>
    $(received)Content-Type: multipart/alternative; boundary="000000000000dd23a50621ff39e8"

    --000000000000dd23a50621ff39e8
    Content-Type: text/plain; charset="UTF-8"

    Hello World!

    Best regards,
    Test User

    --000000000000dd23a50621ff39e8
    Content-Type: text/html; charset="UTF-8"

    <div dir="ltr">Hello World!<div><br></div><div>Best regards,</div><div>Test User</div></div>

    --000000000000dd23a50621ff39e8--"""
end

@testset "Parse Email" begin
    @testset "Case №1: simple email" begin
        data = read("emails/simple.eml")
        email = parse_email(data)

        @test email.from == ["Test User <username@example.com>"]
        @test email.to == ["Test User <username@example.com>"]
        @test email.date == DateTime("1996-03-05 08:00:00", DateFormat("yyyy-mm-dd HH:MM:SS"))
        @test !isempty(email.text_body)
        @test isempty(email.attachments)
    end

    @testset "Case №2: email with attachments" begin
        data = read("emails/attachments.eml")
        email = parse_email(data)

        @test email.from == ["Test User <username@example.com>"]
        @test email.to == ["Test User <username@example.com>"]
        @test email.date == DateTime("1996-03-05 08:00:00", DateFormat("yyyy-mm-dd HH:MM:SS"))
        @test !isempty(email.text_body)
        @test length(email.attachments) == 5
    end

    @testset "Case №3: empty email" begin
        data = read("emails/empty0.msg")
        email = parse_email(data)

        @test email.from == ["Peter Bloomfield <PeterBloomfield@bellsouth.net>"]
        @test email.to == ["Peter Bloomfield <PeterBloomfield@BellSouth.net>"]
        @test email.date == DateTime("2003-12-06 15:41:26", DateFormat("yyyy-mm-dd HH:MM:SS"))
        @test length(email.text_body) == 1
        @test isempty(email.attachments)
    end

    @testset "Case №4: mbox email" begin
        data = read("emails/substring.mbox")
        email = parse_email(data)
        
        @test email.from == ["fejj@gnome.org"]
        @test email.to == ["fejj@gnome.org"]
        @test email.date == DateTime("2002-08-23 06:32:53", DateFormat("yyyy-mm-dd HH:MM:SS"))
        @test !isempty(email.text_body)
        @test isempty(email.attachments)
    end

    @testset "Case №5: mbox email" begin
        data = read("emails/jwz.mbox")
        email = parse_email(data)
        
        @test email.from == ["nsb"]
        @test length(email.to) == 18
        @test email.date == DateTime("1991-09-19 16:41:43", DateFormat("yyyy-mm-dd HH:MM:SS"))
        @test !isempty(email.text_body)
        @test isempty(email.attachments)
    end

    @testset "Case №6: more emails" begin
        email = @test_nowarn parse_email(read("emails/missing_date.eml"))
        @test isnothing(email.date)
        email = @test_nowarn parse_email(read("emails/broken_fields.eml"))
        @test isnothing(email.attachments[1].encoding)
        @test isnothing(email.attachments[1].name)
        @test_nowarn parse_email(read("emails/eml_as_attachment.eml"))
    end

    @testset "Case №7: Time Zones parsing" begin
        date = "Thu, 19 Sep 91 12:41:43"
        format = DateFormat("yyyy-mm-dd HH:MM:SS")

        email_str = gen_email_string(date, "+0300", "(CST)")
        email = parse_email(email_str)
        @test email.date == DateTime("1991-09-19 09:41:43", format)

        email_str = gen_email_string(date, "+0300", "(UDP)")
        email = parse_email(email_str)
        @test email.date == DateTime("1991-09-19 09:41:43", format)

        email_str = gen_email_string(date, "-0300", "(GDP)")
        email = parse_email(email_str)
        @test email.date == DateTime("1991-09-19 15:41:43", format)

        email_str = gen_email_string(date, "(UDP)", "")
        email = parse_email(email_str)
        @test email.date == DateTime("1991-09-19 12:41:43", format)

        email_str = gen_email_string(date, "(EDT)", "")
        email = parse_email(email_str)
        @test email.date == DateTime("1991-09-19 16:41:43", format)

        email_str = gen_email_string(date, "EDT", "")
        email = parse_email(email_str)
        @test email.date == DateTime("1991-09-19 16:41:43", format)
    end
    
    @testset "Case №8: Headers" begin
        date = "Thu, 19 Sep 91 12:41:43"
        format = DateFormat("yyyy-mm-dd HH:MM:SS")

        received = gen_received_string(date, "+0400", "(PDT)")
        email_str = gen_email_string(date, "+0300", "(CST)", received)
        email = parse_email(email_str)

        @test email.date == DateTime("1991-09-19 09:41:43", format)
        @test email.received_at == [DateTime("1991-09-19 08:41:43", format), DateTime("1991-09-19 08:41:43", format)]
        Base.show(stdout, email)
    end
end